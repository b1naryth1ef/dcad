module main;

import std.stdio,
       std.getopt;

import dcad.types;
import opus.encoder;

struct CommandLineArgs {
  int channels = 2;
  int frameRate = 48000;
  int frameSize = 960;
  int bitrate = 128;

  bool fec = true;
  int packetLossPercent = 30;

  bool raw = true;

  string input = "pipe:0";
  string output = "pipe:1";

  bool flush = true;
}

void encode(CommandLineArgs args) {
  assert(args.raw, "Non-raw mode is not supported currently");

  // Create the OPUS Encoder
  Encoder enc = new Encoder(args.frameRate, args.channels);

  // Set some base options
  enc.setBandwidth(Bandwidth.FULLBAND);
  enc.setBitrate(args.bitrate);
  enc.setInbandFEC(args.fec);
  enc.setPacketLossPercent(args.packetLossPercent);

  File input;
  if (args.input == "pipe:0") {
    input = std.stdio.stdin;
  } else {
    input = File(args.input, "r");
  }

  File output;
  if (args.output == "pipe:1") {
    output = std.stdio.stdout;
  } else {
    output = File(args.output, "w");
  }

  short[] rawData;
  rawData.length = (args.frameSize * args.channels);

  short[] data;

  while (true) {
    data = input.rawRead(rawData);

    if (data.length != rawData.length) {
      break;
    }

    Frame(enc.encode(cast(immutable)data, args.frameSize)).write(output);

    if (args.flush) {
      output.flush();
    }
  }

  output.flush();
  output.close();
}

void main(string[] rawargs) {
  CommandLineArgs args;

  auto opts = getopt(
    rawargs,
    "channels|ac", "Number of audio channels (1 = mono, 2 = stero)", &args.channels,
    "rate|ar", "Audio sampling rate", &args.frameRate,
    "size|as", "Audio frame size", &args.frameSize,
    "bitrate|ab", "Audio bitrate", &args.bitrate,
    "fec", "Enable FEC (forward error correction)", &args.fec,
    "packet-loss-percent", "FEC packet loss percent", &args.packetLossPercent,
    "raw", "Don't include DCA metadata/magic bytes (raw OPUS)", &args.raw,
    "input", "Input file or pipe", &args.input,
    "output", "Output file or pipe", &args.output,
    "flush", "Flush output after each frame, assists in real time pipelines", &args.flush,
  );

  if (opts.helpWanted) {
    return defaultGetoptPrinter("DCAD - a DCA audio encoder", opts.options);
  }

  encode(args);

}
