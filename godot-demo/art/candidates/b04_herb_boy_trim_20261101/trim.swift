import Foundation
import AVFoundation
import CoreMedia
import Dispatch

let base=URL(fileURLWithPath:"/Users/leqiong/.codex/visualizations/2026/10/30/01a18d8b-21a1-7251-bedb-d5290779f673/b04-se-8662-trim-v1")
let asset=AVURLAsset(url:base.appendingPathComponent("source-8662.mp4"))
let out=base.appendingPathComponent("B04-SE-attack-8662-trim.mp4")
guard let session=AVAssetExportSession(asset:asset,presetName:AVAssetExportPresetPassthrough) else { fatalError("Cannot create passthrough export session") }
guard session.supportedFileTypes.contains(.mp4) else { fatalError("MP4 passthrough not supported") }
guard !FileManager.default.fileExists(atPath:out.path) else { fatalError("Output already exists; refuse overwrite") }
session.outputURL=out
session.outputFileType = .mp4
session.timeRange=CMTimeRange(start:CMTime(value:10,timescale:24),duration:CMTime(value:84,timescale:24))
let semaphore=DispatchSemaphore(value:0)
session.exportAsynchronously { semaphore.signal() }
semaphore.wait()
print("STATUS",session.status.rawValue)
if let err=session.error { print("ERROR",err) }
if session.status != .completed { exit(1) }
print("EXPORTED",out.path)

