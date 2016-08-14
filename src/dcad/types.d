module dcad.types;

import std.json,
       std.stdio,
       std.bitmanip,
       std.outbuffer;

ubyte[][] rawReadFramesFromFile(File f) {
  ubyte[][] frames;

  while (true) {
    ubyte[] frame = rawReadFrameFromFile(f);
    if (frame.length == 0) break;
    frames ~= frame;
  }

  return frames;
}

ubyte[] rawReadFrameFromFile(File f) {
  ubyte[] data;

  auto frameSize = f.rawRead(new ubyte[2]);
  if (frameSize.length == 0) {
    return data;
  }

  short size = frameSize.read!(short, Endian.littleEndian);
  if (size == 0) {
    return data;
  }

  return f.rawRead(new ubyte[size]);
}

struct Frame {
  ubyte[] data;

  this(ubyte[] data) {
    this.data = data;
  }

  // TODO: deprecate
  @property size_t size() {
    return data.length;
  }

  bool read(File f) {
    this.data = rawReadFrameFromFile(f);

    if (this.data.length == 0) {
      return false;
    }

    return true;
  }

  void write(OutBuffer buffer) {
    buffer.write(nativeToLittleEndian(this.size));
    buffer.write(this.data);
  }

  void write(File file) {
    file.rawWrite(nativeToLittleEndian(this.size));
    file.rawWrite(this.data);
  }
}

class DCAFile {
  DCAFileMeta meta;
  Frame[] frames;

  this() {}

  this(File f) {
    char[3] magicHeader;
    f.rawRead(magicHeader);

    if (cast(string)magicHeader == "DCA") {
      assert(false, "standard DCA files are not supported yet");
    } else {
      f.seek(0);
      this.readOpusDataFile(f);
    }
  }

  this(ubyte[][] rawFrames) {
    foreach (frame; rawFrames) {
      this.frames ~= Frame(frame);
    }
  }

  OutBuffer toOutBuffer() {
    OutBuffer buffer = new OutBuffer;

    foreach (frame; this.frames) {
      frame.write(buffer);
    }

    return buffer;
  }

  void save(string path) {
    File f = File(path, "w");
    f.rawWrite(this.toOutBuffer().toBytes);
    f.close();
  }

  /**
    Creates a new DCAFile without trying to read magic bytes. This is useful
    for file objects that do not support streaming.
  */
  static DCAFile fromRawDCA(File f) {
    DCAFile dca = new DCAFile;
    dca.readOpusDataFile(f);
    return dca;
  }

  private void readOpusDataFile(File f) {
    while (true) {
      Frame frame;

      if (!frame.read(f)) {
        break;
      }

      this.frames ~= frame;
    }
  }
}

class DCAFileMeta {
  DCAMetadata* dca;
  SongInfoMetadata* info;
  OriginMetadata* origin;
  OpusMetadata* opus;
  JSONValue extra;

  this(JSONValue baseObj) {
    this.dca = new DCAMetadata(baseObj["dca"]);
    this.info = new SongInfoMetadata(baseObj["info"]);
    this.origin = new OriginMetadata(baseObj["origin"]);
    this.opus = new OpusMetadata(baseObj["opus"]);
    this.extra = baseObj["extra"];
  }
}

struct DCAMetadata {
  ushort v;
  DCAToolMetadata* tool;

  this(JSONValue obj) {
    this.v = cast(ushort)obj["version"].integer;
    this.tool = new DCAToolMetadata(obj["tool"]);
  }
}

struct DCAToolMetadata {
  string name;
  string v;
  string url;
  string author;

  this(JSONValue obj) {
    this.name = obj["name"].str;
    this.v = obj["version"].str;
    this.url = obj["url"].str;
    this.author = obj["author"].str;
  }
}

struct SongInfoMetadata {
  string title;
  string artist;
  string album;
  string genre;
  string comments;
  string cover;

  this(JSONValue obj) {
    this.title = obj["title"].str;
    this.artist = obj["artist"].str;
    this.album = obj["album"].str;
    this.genre = obj["genre"].str;
    this.comments = obj["comments"].str;
    if (!obj["cover"].isNull) {
      this.cover = obj["cover"].str;
    }
  }
}

struct OriginMetadata {
  string source;
  uint bitrate;
  ushort channels;
  string encoding;
  string url;

  this(JSONValue obj) {
    this.source = obj["source"].str;
    this.bitrate = cast(uint)obj["abr"].integer;
    this.channels = cast(ushort)obj["channels"].integer;
    this.encoding = obj["encoding"].str;
    this.url = obj["url"].str;
  }
}

struct OpusMetadata {
  string mode;
  uint bitrate;
  uint sampleRate;
  uint frameSize;
  ushort channels;

  this(JSONValue obj) {
    this.mode = obj["mode"].str;
    this.bitrate = cast(uint)obj["abr"].integer;
    this.sampleRate = cast(uint)obj["sample_rate"].integer;
    this.frameSize = cast(uint)obj["frame_size"].integer;
    this.channels = cast(ushort)obj["channels"].integer;
  }
}

unittest {
  auto obj = parseJSON(`{ "dca": { "version": 1, "tool": {  "name": "dca-encoder",  "version": "1.0.0",  "url": "https://github.com/bwmarrin/dca/",  "author": "bwmarrin" } }, "opus": { "mode": "voip", "sample_rate": 48000, "frame_size": 960, "abr": 64000, "vbr": true, "channels": 2 }, "info": { "title": "Out of Control", "artist": "Nothing's Carved in Stone", "album": "Revolt", "genre": "jrock", "comments": "Second Opening for the anime Psycho Pass", "cover": null }, "origin": { "source": "file", "abr": 192000, "channels": 2, "encoding": "MP3/MPEG-2L3", "url": "https://www.dropbox.com/s/bwc73zb44o3tj3m/Out%20of%20Control.mp3?dl=0" }, "extra": {}}`);

  auto file = new DCAFileMeta(obj);
  assert(file.dca.v == 1);
  assert(file.dca.tool.author == "bwmarrin");
  assert(file.opus.mode == "voip");
  assert(file.info.genre == "jrock");
  assert(file.origin.source == "file");

  auto dca = new DCAFile(File("test/airhorn_default.dca", "r"));
}
