//
//  BooleanAttribute.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

/**
 * A boolean attribute that is written out without any value.
 */
open class BooleanAttribute: Attribute {
    /**
     * Create a new boolean attribute from unencoded (raw) key.
     * @param key attribute key
     */
    @usableFromInline
    init(key: [UInt8]) throws {
        try super.init(key: key, value: [])
    }

    override public func isBooleanAttribute() -> Bool {
        return true
    }
}
