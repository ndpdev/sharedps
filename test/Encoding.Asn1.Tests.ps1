function hexString([string]$str) { return (@($str.ToCharArray() | ForEach-Object {([byte]$_).ToString('X2')}) -join '') }
function binHex([string]$str) { [byte[]]$out = [Array]::CreateInstance([byte], $str.Length / 2); for ($i = 0; $i -lt $out.Length; ++$i) { $out[$i] = [byte]::Parse($str.Substring($i * 2, 2), [Globalization.NumberStyles]::HexNumber) }; return $out }
function hexBin([byte[]]$arr) { return [String]::Join([String]::Empty, [Linq.Enumerable]::Select($arr,[Func[byte,string]]{$args[0].ToString('X2')})) }

describe 'X.690 Example Bit String [8.6.4.2]' {

    context 'Primitive Encoding' {

        $asn1Data = binHex '0307040A3B5F291CD0'
        $asn1Type = [Asn1Type]::ReadTag($asn1Data)
    
        it 'should have Universal class' { $asn1Type.GetClassName() | should be 'Universal' }
        it 'should have Primitive encoding' { $asn1Type.GetEncoding() | should be 'Primitive' }
        it 'should have BitString tag name' { $asn1Type.GetTagName() | should be 'BitString' }
    
        #TODO: Asn1Type needs to parse BITSTRING value
        it 'should have ''0A3B5F291CD''H value' { [Convert]::ToBase64String($asn1Type.Value) | should be 'BAo7Xykc0A==' }
    }

    context 'Constructed Encoding' {

        $asn1Data = binHex '23800303000A3B0305045F291CD00000'
        $asn1Type = [Asn1Type]::ReadTag($asn1Data)
    
        it 'should have Universal class' { $asn1Type.GetClassName() | should be 'Universal' }
        it 'should have Constructed encoding' { $asn1Type.GetEncoding() | should be 'Constructed' }
        it 'should have undefined length' { $asn1Type.Length | should be -1 }
        it 'should have BitString tag name' { $asn1Type.GetTagName() | should be 'BitString' }
        it 'should contain two Asn1Type values' { $asn1Type.Value.Count | should be 2 }
    
        $node = $asn1Type.Value.First
        it 'should have first value of 000A3B' { hexBin $node.Value.Value | should be '000A3B' }
    
        $node = $node.Next
        it 'should have second value of 045F291CD0' { hexBin $node.Value.Value | should be '045F291CD0' }
    }
}

describe 'X.690 Example Sequence [8.9.3]' {

    $asn1Data = binHex '300A1605536D6974680101FF'
    $asn1Type = [Asn1Type]::ReadTag($asn1Data)

    context 'SEQUENCE {name IA5String, ok BOOLEAN}' {

        it 'should have tag name of Asn1Sequence' { $asn1Type.GetTagName() | should be 'Asn1Sequence' }
        it 'should have encoding of Constructed' { $asn1Type.GetEncoding() | should be 'Constructed' }

        $node = $asn1Type.Value.First
        context 'name IA5String' {
            $innerType = $node.Value
            it 'should have tag name of IA5String' { $innerType.GetTagName() | should be 'IA5String' }
            it 'should have value of ''Smith''' { [Text.Encoding]::ASCII.GetString($innerType.Value) | should be 'Smith' }
        }
    
        $node = $node.Next
        context 'ok BOOLEAN' {
            $innerType = $node.Value
            it 'should have tag name of Boolean' { $innerType.GetTagName() | should be 'Boolean' }
            it 'should have value of true' { $innerType.Value[0] | should be 0xFF }
        }
    }
}

describe 'X.690 Example Encoding of a Prefixed Type Value [8.14]' {

    context 'Type1 ::= VisibleString' {
        $asn1Type1 = [Asn1Type]::ReadTag((binHex '1A054A6F6E6573'))
        it 'should have tag name of VisibleString' { $asn1Type1.GetTagName() | should be 'VisibleString' }
        it 'should have value of ''Jones''' { [Text.Encoding]::ASCII.GetString($asn1Type1.Value) | should be 'Jones' }
    }

    context 'Type2 ::= [APPLICATION 3] IMPLICIT Type1' {
        $asn1Type2 = [Asn1Type]::ReadTag((binHex '43054A6F6E6573'))
        it 'should have tag name of [Application 3]' { $asn1Type2.GetTagName() | should be '[Application 3]' }
        it 'should have implicit value of ''Jones''' { [Text.Encoding]::ASCII.GetString($asn1Type2.Value) | should be 'Jones' }
    }

    context 'Type3 ::= [2] Type2' {
        $asn1Type3 = [Asn1Type]::ReadTag((binHex 'A20743054A6F6E6573'))
        it 'should have tag name of [ContextSpecific 2]' { $asn1Type3.GetTagName() | should be '[ContextSpecific 2]' }
        it 'should have encoding of Constructed' { $asn1Type3.GetEncoding() | should be 'Constructed' }
        it 'should have one encoded value' { $asn1Type3.Value.Count | should be 1 }
        it 'should have encoded tag name of [Application 3]' { $asn1Type3.Value.First.Value.GetTagName() | should be '[Application 3]' }
        it 'should have encoded implicit value of ''Jones''' { [Text.Encoding]::ASCII.GetString($asn1Type3.Value.First.Value.Value) | should be 'Jones' }
    }

    context 'Type4 ::= [APPLICATION 7] IMPLICIT Type3' {
        $asn1Type4 = [Asn1Type]::ReadTag((binHex '670743054A6F6E6573'))
        it 'should have tag name of [Application 7]' { $asn1Type4.GetTagName() | should be '[Application 7]' }
        it 'should have encoding of Constructed' { $asn1Type4.GetEncoding() | should be 'Constructed' }
        it 'should have one encoded value' { $asn1Type4.Value.Count | should be 1 }
        it 'should have encoded tag name of [Application 3]' { $asn1Type4.Value.First.Value.GetTagName() | should be '[Application 3]' }
        it 'should have encoded implicit value of ''Jones''' { [Text.Encoding]::ASCII.GetString($asn1Type4.Value.First.Value.Value) | should be 'Jones' }
    }

    context 'Type5 ::= [2] IMPLICIT Type2' {
        $asn1Type5 = [Asn1Type]::ReadTag((binHex '82054A6F6E6573'))
        it 'should have tag name of [ContextSpecific 2]' { $asn1Type5.GetTagName() | should be '[ContextSpecific 2]' }
        it 'should have implicit value of ''Jones''' { [Text.Encoding]::ASCII.GetString($asn1Type5.Value) | should be 'Jones' }
    }
}

describe 'X.690 Example Record Structure [A.3]' {
    
    $asn1Data = [IO.MemoryStream]::new([Convert]::FromBase64String('YIGFYRAaBEpvaG4aAVAaBVNtaXRooAoaCERpcmVjdG9yQgEzoQpDCDE5NzEwOTE3ohJhEBoETWFyeRoBVBoFU21pdGijQjEfYREaBVJhbHBoGgFUGgVTbWl0aKAKQwgxOTU3MTExMTEfYREaBVN1c2FuGgFCGgVKb25lc6AKQwgxOTU5MDcxNw=='))
    $asn1Type = [Asn1Type]::ReadTagFromStream($asn1Data)
    #$asn1Type.ToDebugString()

    it 'should have {name {givenName}} value of John' {
        [Text.Encoding]::ASCII.GetString($asn1Type.Value[0].Value[0].Value) | should be 'John'
    }
}
