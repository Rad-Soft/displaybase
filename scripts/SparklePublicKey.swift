//
//  SparklePublicKey.swift
//  Displaybase
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import CryptoKit
import Foundation

let encoded = ProcessInfo.processInfo.environment["SPARKLE_ED_PRIVATE_KEY"] ?? ""
guard let seed = Data(base64Encoded: encoded), seed.count == 32 else {
    FileHandle.standardError.write(Data("SPARKLE_ED_PRIVATE_KEY isn't a 32 byte seed.\n".utf8))
    exit(1)
}
let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
print(key.publicKey.rawRepresentation.base64EncodedString())
