//
//  ImageCompression.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa

import TelegramCore
import SyncCore
import Postbox
import TGUIKit
import MurMurHash32

public struct TinyThumbnailData: Equatable {
    let tablesDataHash: Int32
    let data: Data
}

private let fixedTablesData = dataWithHexString("ffd8ffdb004300281c1e231e19282321232d2b28303c64413c37373c7b585d4964918099968f808c8aa0b4e6c3a0aadaad8a8cc8ffcbdaeef5ffffff9bc1fffffffaffe6fdfff8ffdb0043012b2d2d3c353c76414176f8a58ca5f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c11552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a636465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f0100030101010101010101010000000000000102030405060708090a0bffc400b51100020102040403040705040400010277000102031104052131061241510761711322328108144291a1b1c109233352f0156272d10a162434e125f11718191a262728292a35363738393a434445464748494a535455565758595a636465666768696a737475767778797a82838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffd9")

private let fixedTablesDataHash: Int32 = murMurHash32Data(fixedTablesData)

private struct my_error_mgr {
    var pub = jpeg_error_mgr()
}

func decompressTinyThumbnail(data: TinyThumbnailData) -> CGImage? {
    if data.tablesDataHash != fixedTablesDataHash {
        return nil
    }
    
    var cinfo = jpeg_decompress_struct()
    var jerr = my_error_mgr()
    
    cinfo.err = jpeg_std_error(&jerr.pub)
    //jerr.pub.error_exit = my_error_exit
    
    /* Establish the setjmp return context for my_error_exit to use. */
    /*if (setjmp(jerr.setjmp_buffer)) {
     /* If we get here, the JPEG code has signaled an error.
     * We need to clean up the JPEG object, close the input file, and return.
     */
     jpeg_destroy_decompress(&cinfo);
     fclose(infile);
     return 0;
     }*/
    
    /* Now we can initialize the JPEG decompression object. */
    jpeg_CreateDecompress(&cinfo, JPEG_LIB_VERSION, MemoryLayout.size(ofValue: cinfo))
    
    /* Step 2: specify data source (eg, a file) */
    
    let fixedTablesDataLength = UInt(fixedTablesData.count)
    fixedTablesData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
        jpeg_mem_src(&cinfo, bytes, fixedTablesDataLength)
        jpeg_read_header(&cinfo, 0)
    }
    
    let result = data.data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> CGImage? in
        jpeg_mem_src(&cinfo, bytes, fixedTablesDataLength)
        jpeg_read_header(&cinfo, 1)
        jpeg_start_decompress(&cinfo)
        let rowStride = Int(cinfo.output_width) * 3
        var tempBuffer = malloc(rowStride)!.assumingMemoryBound(to: UInt8.self)
        defer {
            free(tempBuffer)
        }
        let context = DrawingContext(size: CGSize(width: CGFloat(cinfo.output_width), height: CGFloat(cinfo.output_height)), scale: 1.0, clear: false)
        while cinfo.output_scanline < cinfo.output_height {
            let rowPointer = context.bytes.assumingMemoryBound(to: UInt8.self).advanced(by: Int(cinfo.output_scanline) * context.bytesPerRow)
            var row: JSAMPROW? = UnsafeMutablePointer(tempBuffer)
            jpeg_read_scanlines(&cinfo, &row, 1)
            for x in 0 ..< Int(cinfo.output_width) {
                rowPointer[x * 4 + 3] = 255
                for i in 0 ..< 3 {
                    rowPointer[x * 4 + i] = tempBuffer[x * 3 + i]
                }
            }
        }
        return context.generateImage()
    }
    
    jpeg_finish_decompress(&cinfo)
    jpeg_destroy_decompress(&cinfo)
    
    return result
}

private let tinyThumbnailHeaderPattern = Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDACgcHiMeGSgjISMtKygwPGRBPDc3PHtYXUlkkYCZlo+AjIqgtObDoKrarYqMyP/L2u71////m8H////6/+b9//j/2wBDASstLTw1PHZBQXb4pYyl+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj/wAARCAAAAAADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwA=")
private let tinyThumbnailFooterPattern = Data(base64Encoded: "/9k=")

func decodeTinyThumbnail(data: Data) -> Data? {
    if data.count < 3 {
        return nil
    }
    guard let tinyThumbnailHeaderPattern = tinyThumbnailHeaderPattern, let tinyThumbnailFooterPattern = tinyThumbnailFooterPattern else {
        return nil
    }
    var version: UInt8 = 0
    data.copyBytes(to: &version, count: 1)
    if version != 1 {
        return nil
    }
    var width: UInt8 = 0
    var height: UInt8 = 0
    data.copyBytes(to: &width, from: 1 ..< 2)
    data.copyBytes(to: &height, from: 2 ..< 3)
    
    var resultData = Data()
    resultData.append(tinyThumbnailHeaderPattern)
    resultData.append(data.subdata(in: 3 ..< data.count))
    resultData.append(tinyThumbnailFooterPattern)
    resultData.withUnsafeMutableBytes({ (resultBytes: UnsafeMutablePointer<UInt8>) -> Void in
        resultBytes[164] = width
        resultBytes[166] = height
    })
    return resultData
}

func serializeTinyThumbnail(_ data: TinyThumbnailData) -> String {
    var result = "TTh1 \(data.data.count) bytes\n"
    result.append(String(data.tablesDataHash, radix: 16))
    result.append(data.data.base64EncodedString())
    let parsed = parseTinyThumbnail(result)
    assert(parsed == data)
    return result
}

func parseTinyThumbnail(_ text: String) -> TinyThumbnailData? {
    if text.hasPrefix("TTh1") && text.count > 20 {
        guard let startIndex = text.range(of: "\n")?.upperBound else {
            return nil
        }
        let start = startIndex.encodedOffset
        guard let hash = Int32(String(text[text.index(text.startIndex, offsetBy: start) ..< text.index(text.startIndex, offsetBy: start + 8)]), radix: 16) else {
            return nil
        }
        guard let data = Data(base64Encoded: String(text[text.index(text.startIndex, offsetBy: start + 8)...])) else {
            return nil
        }
        return TinyThumbnailData(tablesDataHash: hash, data: data)
    }
    return nil
}
