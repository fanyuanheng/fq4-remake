import AppKit
import Foundation

struct FQ4ClassSpritePage: Equatable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    var image: NSImage? {
        guard pixels.count == width * height,
              let representation = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: width,
                  pixelsHigh: height,
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: width * 4,
                  bitsPerPixel: 32
              ),
              let bitmap = representation.bitmapData
        else {
            return nil
        }

        for (index, colourIndex) in pixels.enumerated() {
            let colour = Self.palette[Int(colourIndex)]
            let destination = index * 4
            bitmap[destination] = colour.red
            bitmap[destination + 1] = colour.green
            bitmap[destination + 2] = colour.blue
            bitmap[destination + 3] = colour.alpha
        }

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(representation)
        return image
    }

    private struct PaletteColour {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    // Character patterns use a game-programmed eight-colour palette. Index
    // zero is transparent; index three is the near-black outline/hair colour.
    private static let palette: [PaletteColour] = [
        .init(red: 0, green: 0, blue: 0, alpha: 0),
        .init(red: 0, green: 112, blue: 128, alpha: 255),
        .init(red: 214, green: 92, blue: 0, alpha: 255),
        .init(red: 0, green: 0, blue: 0, alpha: 255),
        .init(red: 0, green: 150, blue: 0, alpha: 255),
        .init(red: 100, green: 170, blue: 175, alpha: 255),
        .init(red: 240, green: 190, blue: 0, alpha: 255),
        .init(red: 244, green: 244, blue: 226, alpha: 255),
    ]
}

struct FQ4ClassSpriteArchive {
    enum ArchiveError: LocalizedError, Equatable {
        case truncatedIndex
        case invalidIndex
        case truncatedLayoutTable
        case missingClass(Int)
        case unsupportedCompression(Int)
        case corruptClass(Int)
        case invalidSpritePage(Int)

        var errorDescription: String? {
            switch self {
            case .truncatedIndex, .invalidIndex:
                return "CHRBANK has an invalid class index."
            case .truncatedLayoutTable:
                return "MAIN.EXE has an invalid class-sprite layout table."
            case .missingClass(let code):
                return String(format: "Class %02X has no sprite data.", code)
            case .unsupportedCompression(let mode):
                return "CHRBANK compression mode \(mode) is unsupported."
            case .corruptClass(let code):
                return String(format: "Class %02X sprite data is corrupt.", code)
            case .invalidSpritePage(let code):
                return String(format: "Class %02X has no renderable sprite page.", code)
            }
        }
    }

    static let entryCount = 256
    static let indexSize = entryCount * 2
    static let layoutMapOffset = 0x2E47A
    static let dimensionsOffset = 0x2E57A
    static let frameCountsOffset = 0x2E58A
    static let layoutCount = 16

    private let bytes: [UInt8]
    private let entries: [Range<Int>?]
    private let layouts: [Layout]

    init(data: Data, mainExecutableData: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count >= Self.indexSize else {
            throw ArchiveError.truncatedIndex
        }

        var entries: [Range<Int>?] = []
        var offset = Self.indexSize
        for index in 0..<Self.entryCount {
            let lengthOffset = index * 2
            let length = Int(bytes[lengthOffset])
                | (Int(bytes[lengthOffset + 1]) << 8)
            guard offset <= bytes.count, length <= bytes.count - offset else {
                throw ArchiveError.invalidIndex
            }
            entries.append(length == 0 ? nil : offset..<(offset + length))
            offset += length
        }
        guard offset == bytes.count else {
            throw ArchiveError.invalidIndex
        }

        let executable = [UInt8](mainExecutableData)
        guard executable.count >= Self.frameCountsOffset + Self.layoutCount,
              executable.count >= Self.layoutMapOffset + Self.entryCount
        else {
            throw ArchiveError.truncatedLayoutTable
        }

        var layouts: [Layout] = []
        for classCode in 0..<Self.entryCount {
            let layoutIndex = Int(executable[Self.layoutMapOffset + classCode])
            guard layoutIndex < Self.layoutCount else {
                throw ArchiveError.truncatedLayoutTable
            }
            let packedDimensions = executable[
                Self.dimensionsOffset + layoutIndex
            ]
            let columns = Int(packedDimensions & 0x0F)
            let rows = Int(packedDimensions >> 4)
            let frameCount = Int(
                executable[Self.frameCountsOffset + layoutIndex]
            )
            guard columns > 0, rows > 0, frameCount > 0 else {
                throw ArchiveError.truncatedLayoutTable
            }
            layouts.append(
                Layout(
                    columns: columns,
                    rows: rows,
                    frameCount: frameCount
                )
            )
        }

        self.bytes = bytes
        self.entries = entries
        self.layouts = layouts
    }

    func decodedPatternData(for classCode: Int) throws -> Data {
        guard entries.indices.contains(classCode),
              let range = entries[classCode]
        else {
            throw ArchiveError.missingClass(classCode)
        }

        do {
            let block = Array(bytes[range])
            guard block.count >= 2 else {
                throw ArchiveError.corruptClass(classCode)
            }
            let mode = Self.uint16(block, at: 0)
            var payload = Array(block.dropFirst(2))
            let pipeline: [([UInt8]) throws -> [UInt8]]

            switch mode {
            case 1:
                pipeline = [Self.decodeRLE]
            case 2:
                pipeline = [Self.decodeHuffman]
            case 3:
                pipeline = [Self.decodeLZ]
            case 4:
                pipeline = [Self.decodeHuffman, Self.decodeRLE]
            case 5:
                pipeline = [Self.decodeLZ, Self.decodeRLE]
            case 6:
                pipeline = [Self.decodeRLE, Self.decodeHuffman]
            case 7:
                pipeline = [Self.decodeLZ, Self.decodeHuffman]
            case 8:
                pipeline = [Self.decodeRLE, Self.decodeLZ]
            case 9:
                pipeline = [Self.decodeHuffman, Self.decodeLZ]
            default:
                throw ArchiveError.unsupportedCompression(mode)
            }

            for decode in pipeline {
                payload = try decode(payload)
            }
            return Data(payload)
        } catch let error as ArchiveError {
            throw error
        } catch {
            throw ArchiveError.corruptClass(classCode)
        }
    }

    func representativePage(for classCode: Int) throws -> FQ4ClassSpritePage {
        let decoded = [UInt8](try decodedPatternData(for: classCode))
        guard layouts.indices.contains(classCode) else {
            throw ArchiveError.invalidSpritePage(classCode)
        }
        let layout = layouts[classCode]
        let cellWidth = 16
        let cellHeight = 16
        let planeBytesPerCell = (cellWidth / 8) * cellHeight
        let planeCount = 3
        let bytesPerCell = planeBytesPerCell * planeCount
        let cellsPerFrame = layout.columns * layout.rows
        let bytesPerFrame = cellsPerFrame * bytesPerCell
        guard decoded.count == bytesPerFrame * layout.frameCount else {
            throw ArchiveError.invalidSpritePage(classCode)
        }

        let width = layout.columns * cellWidth
        let height = layout.rows * cellHeight
        let representativeFrame = min(4, layout.frameCount - 1)
        let frameOffset = representativeFrame * bytesPerFrame
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let cellX = x / cellWidth
                let cellY = y / cellHeight
                let localX = x % cellWidth
                let localY = y % cellHeight
                let cellIndex = (cellY * layout.columns) + cellX
                var colour: UInt8 = 0
                for plane in 0..<planeCount {
                    let source = frameOffset
                        + (cellIndex * bytesPerCell)
                        + (plane * planeBytesPerCell)
                        + (localY * (cellWidth / 8))
                        + (localX / 8)
                    let bit = (
                        decoded[source] >> UInt8(7 - (localX % 8))
                    ) & 1
                    colour |= bit << UInt8(plane)
                }
                pixels[(y * width) + x] = colour
            }
        }
        return FQ4ClassSpritePage(width: width, height: height, pixels: pixels)
    }

    private struct Layout {
        let columns: Int
        let rows: Int
        let frameCount: Int
    }

    private static func decodeRLE(_ source: [UInt8]) throws -> [UInt8] {
        var cursor = Cursor(source)
        let marker = UInt8(truncatingIfNeeded: try cursor.readUInt16())
        var remaining = Int(try cursor.readUInt16())
        var output: [UInt8] = []
        output.reserveCapacity(remaining)

        while remaining > 0 {
            let byte = try cursor.readByte()
            if byte != marker {
                output.append(byte)
                remaining -= 1
                continue
            }

            let value = try cursor.readByte()
            let encodedCount = Int(try cursor.readByte())
            let count = encodedCount == 0 ? 256 : encodedCount
            guard count <= remaining else {
                throw DecodeError.invalidData
            }
            output.append(contentsOf: repeatElement(value, count: count))
            remaining -= count
        }
        return output
    }

    private static func decodeLZ(_ source: [UInt8]) throws -> [UInt8] {
        var cursor = Cursor(source)
        let markerWord = try cursor.readUInt16()
        let marker = UInt8(truncatingIfNeeded: markerWord)
        let distanceBits = 12 - Int(markerWord >> 8)
        guard (1...12).contains(distanceBits) else {
            throw DecodeError.invalidData
        }
        let distanceMask = (1 << distanceBits) - 1
        var remaining = Int(try cursor.readUInt16())
        var output: [UInt8] = []
        output.reserveCapacity(remaining)

        while remaining > 0 {
            let byte = try cursor.readByte()
            if byte != marker {
                output.append(byte)
                remaining -= 1
                continue
            }

            let token = Int(try cursor.readUInt16())
            if token == 1 {
                output.append(marker)
                remaining -= 1
                continue
            }

            var distance = token & distanceMask
            if distance == 0 {
                distance = distanceMask + 1
            }
            let count = (token >> distanceBits) + 4
            guard distance <= output.count, count <= remaining else {
                throw DecodeError.invalidData
            }
            for _ in 0..<count {
                output.append(output[output.count - distance])
            }
            remaining -= count
        }
        return output
    }

    private static func decodeHuffman(_ source: [UInt8]) throws -> [UInt8] {
        guard source.count >= 2 else {
            throw DecodeError.truncated
        }
        let patchCount = uint16(source, at: 0)
        let treeOffset = patchCount == 0 ? 2 : 2 + (patchCount * 3)
        guard treeOffset + 4 <= source.count else {
            throw DecodeError.truncated
        }

        let bitStreamOffset = uint16(source, at: treeOffset)
        let outputCount = uint16(source, at: treeOffset + 2)
        let tableOffset = treeOffset + 4
        var bitCursor = treeOffset + bitStreamOffset
        var bitByte: UInt8 = 0
        var remainingBits = 0
        var output: [UInt8] = []
        output.reserveCapacity(outputCount)

        for _ in 0..<outputCount {
            var node = 0
            var traversalCount = 0
            while true {
                if remainingBits == 0 {
                    guard bitCursor < source.count else {
                        throw DecodeError.truncated
                    }
                    bitByte = source[bitCursor]
                    bitCursor += 1
                    remainingBits = 8
                }

                let bit = Int((bitByte >> 7) & 1)
                bitByte <<= 1
                remainingBits -= 1

                let childOffset = tableOffset + (node * 4) + (bit * 2)
                guard childOffset + 2 <= source.count else {
                    throw DecodeError.truncated
                }
                let child = uint16(source, at: childOffset)
                if child >> 8 == 0xFF {
                    output.append(UInt8(truncatingIfNeeded: child))
                    break
                }

                node = child
                traversalCount += 1
                guard traversalCount <= 256 else {
                    throw DecodeError.invalidData
                }
            }
        }

        for patch in 0..<patchCount {
            let patchOffset = 2 + (patch * 3)
            guard patchOffset + 3 <= source.count else {
                throw DecodeError.truncated
            }
            let value = source[patchOffset]
            let outputOffset = uint16(source, at: patchOffset + 1)
            guard output.indices.contains(outputOffset) else {
                throw DecodeError.invalidData
            }
            output[outputOffset] = value
        }
        return output
    }

    private static func uint16(_ bytes: [UInt8], at offset: Int) -> Int {
        Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
    }

    private enum DecodeError: Error {
        case truncated
        case invalidData
    }

    private struct Cursor {
        let bytes: [UInt8]
        var offset = 0

        init(_ bytes: [UInt8]) {
            self.bytes = bytes
        }

        mutating func readByte() throws -> UInt8 {
            guard offset < bytes.count else {
                throw DecodeError.truncated
            }
            defer { offset += 1 }
            return bytes[offset]
        }

        mutating func readUInt16() throws -> Int {
            let low = Int(try readByte())
            let high = Int(try readByte())
            return low | (high << 8)
        }
    }
}
