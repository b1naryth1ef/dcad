# dcad
dcad is a D-lang implementation of the [DCA](https://github.com/bwmarrin/dca) (Discord Audio) format.

## Example

```d
import dcad : DCAFile;

auto myFile = DCAFile(File("/tmp/lol.dca", "r"));
assert(myFile.frames.length > 0);
```
