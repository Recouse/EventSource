//
//  EventSourceEOL.swift
//  EventSource
//
//  Created by JadianZheng on 2025/7/24.
//

import Foundation

/*
 * https://html.spec.whatwg.org/multipage/server-sent-events.html#server-sent-events
 *
 * Event Stream Format (ABNF):
 * stream        = [ bom ] *event
 * event         = *( comment / field ) end-of-line
 * comment       = colon *any-char end-of-line
 * field         = 1*name-char [ colon [ space ] *any-char ] end-of-line
 * end-of-line   = ( cr lf / cr / lf )
 *
 * ; characters
 * lf            = %x000A ; U+000A LINE FEED (LF)
 * cr            = %x000D ; U+000D CARRIAGE RETURN (CR)
 * space         = %x0020 ; U+0020 SPACE
 * colon         = %x003A ; U+003A COLON (:)
 * bom           = %xFEFF ; U+FEFF BYTE ORDER MARK
 * name-char     = %x0000-0009 / %x000B-000C / %x000E-0039 / %x003B-10FFFF
 *                 ; a scalar value other than U+000A LINE FEED (LF), U+000D CARRIAGE RETURN (CR), or U+003A COLON (:)
 * any-char      = %x0000-0009 / %x000B-000C / %x000E-10FFFF
 *                 ; a scalar value other than U+000A LINE FEED (LF) or U+000D CARRIAGE RETURN (CR)
 */

let lf: UInt8 = 0x0A    // \n
let cr: UInt8 = 0x0D    // \r
let colon: UInt8 = 0x3A // :

let singleSeparators: [[UInt8]] = [
    [cr, lf],   // \r\n
    [cr],       // \r
    [lf]        // \n
].sorted { $0.count > $1.count }

let doubleSeparators: [[UInt8]] = [
    [cr, lf, cr, lf],   // \r\n\r\n
    [lf, cr, lf],       // \n\r\n
    [cr, cr, lf],       // \r\r\n
    [cr, lf, lf],       // \r\n\n
    [cr, lf, cr],       // \r\n\r
    [cr, cr],           // \r\r
    [lf, lf]            // \n\n
].sorted { $0.count > $1.count }
