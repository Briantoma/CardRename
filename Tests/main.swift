import Foundation

// Naming rule tests on fake card folders. Run with ./build.sh test

let fm = FileManager.default
let base = fm.temporaryDirectory.appendingPathComponent("cardrename-tests-\(getpid())")
var failures = 0

func make(_ path: String, date: String = "2026-09-16 09:00", text: String = "") {
    let url = base.appendingPathComponent(path)
    try! fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! text.write(to: url, atomically: true, encoding: .utf8)
    let format = DateFormatter()
    format.dateFormat = "yyyy-MM-dd HH:mm"
    try! fm.setAttributes([.modificationDate: format.date(from: date)!], ofItemAtPath: url.path)
}

func check(_ name: String, _ card: String, max: Int = 15, expect: CardScan.Proposal) {
    let got = CardScan.analyze(root: base.appendingPathComponent(card), maxLength: max)
    if got == expect { print("ok    \(name)") } else { print("FAIL  \(name): got \(got), expected \(expect)"); failures += 1 }
}

func expectTrue(_ name: String, _ value: Bool) {
    if value { print("ok    \(name)") } else { print("FAIL  \(name)"); failures += 1 }
}

make("xd/XDROOT/Clip/D902C001_260916JN.MXF")
make("xd/XDROOT/Clip/D902C001_260916JNM01.XML")
make("fx3/PRIVATE/M4ROOT/Clip/C0001.MP4", date: "2026-09-15 10:30")
make("fx3/PRIVATE/M4ROOT/Clip/C0002.MP4")
make("fx3/PRIVATE/M4ROOT/Clip/C0001M01.XML", text: #"<Device manufacturer="Sony" modelName="ILME-FX3" serialNo="1"/>"#)
make("dji/DCIM/DJI_001/DJI_20260914101010_0001_D.MP4", date: "2026-09-14 10:10")
make("dji/DCIM/DJI_001/DJI_20260914101010_0001_D.LRF")
make("dji2/DCIM/100MEDIA/DJI_0001.MP4", date: "2026-09-13 12:00")
make("ronin/E003_P5M025/E003C0001_261031_P5M025.MOV")
make("ronin/E003_P5M025/E003C0002_261031_P5M025.MOV")
make("red/A003_0916AB.RDM/A003_C001_0916AB.RDC/A003_C001_0916AB_001.R3D")
make("bmd/A007_09161234_C001.braw")
make("arri/B012R1AB/B012C004_260916_R1AB/B012C004_260916_R1AB.0000001.ari")
make("gopro/DCIM/100GOPRO/GX010001.MP4")
make("mix/XDROOT/Clip/A001C001_x.MXF")
make("mix/XDROOT/Clip/A002C001_x.MXF")
try! fm.createDirectory(at: base.appendingPathComponent("empty/DCIM"), withIntermediateDirectories: true)
make("hidden/.Spotlight-V100/A009C001_x.MXF")
make("hidden/DCIM/100CANON/MVI_0001.MOV")
make("deep/1/2/3/4/5/A001C001_x.MXF")

check("Sony XDCAM reel", "xd", expect: .reel("D902"))
check("Sony FX3 C0001 naming", "fx3", expect: .noReel(suggestion: "FX3_260915"))
check("DJI new naming", "dji", expect: .noReel(suggestion: "DJI_260914"))
check("DJI old naming on FAT32", "dji2", max: 11, expect: .noReel(suggestion: "DJI_260913"))
check("DJI Ronin reel", "ronin", expect: .reel("E003"))
check("RED reel", "red", expect: .reel("A003"))
check("Blackmagic reel", "bmd", expect: .reel("A007"))
check("ARRI reel", "arri", expect: .reel("B012"))
check("GoPro on FAT32 drops the underscore", "gopro", max: 11, expect: .noReel(suggestion: "GOPRO260916"))
check("two reels", "mix", expect: .multipleReels(["A001", "A002"]))
check("empty card", "empty", expect: .noClips)
check("hidden folders skipped", "hidden", expect: .noReel(suggestion: "CANON_260916"))
check("clips deeper than 5 levels ignored", "deep", expect: .noClips)

let defaults = ["UNTITLED", " NO NAME", "NONAME", "DJI "]
for name in ["UNTITLED", "Untitled 2", "NO NAME", "NO NAME 1", "DJI", "DJI 1", "DJI2", "NONAME12"] {
    expectTrue("default name \(name)", CardScan.isDefaultName(name, defaults: defaults))
}
for name in ["D901", "E003", "UNTITLED_X", "DJI_260914", "Macintosh HD"] {
    expectTrue("not a default name \(name)", !CardScan.isDefaultName(name, defaults: defaults))
}
expectTrue("looks like card: ronin (no fixed folder)", CardScan.looksLikeCard(base.appendingPathComponent("ronin")))
expectTrue("looks like card: fx3", CardScan.looksLikeCard(base.appendingPathComponent("fx3")))
make("stick/notes/holiday.mp4")
expectTrue("not a card: USB stick with a video", !CardScan.looksLikeCard(base.appendingPathComponent("stick")))
expectTrue("label limits", CardScan.maxLabelLength(fsType: "exfat") == 15 && CardScan.maxLabelLength(fsType: "msdos") == 11)
expectTrue("statfs of /", VolumeInfo(path: "/")?.fsType == "apfs")

try? fm.removeItem(at: base)
print(failures == 0 ? "\nAll tests passed" : "\n\(failures) failed")
exit(failures == 0 ? 0 : 1)
