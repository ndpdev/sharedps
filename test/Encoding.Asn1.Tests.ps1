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
        #TODO: Asn1Type needs to parse BITSTRING values
        #Value should be 0A3B5F291CD
        it 'should have value of 0A3B5F291CD' { [Convert]::ToBase64String($asn1Type.RawValue) | should be 'BAo7Xykc0A==' }
    }
    context 'Constructed Encoding' {
        $asn1Data = binHex '23800303000A3B0305045F291CD00000'
        $asn1Type = [Asn1Type]::ReadTag($asn1Data)
        it 'should have Universal class' { $asn1Type.GetClassName() | should be 'Universal' }
        it 'should have Constructed encoding' { $asn1Type.GetEncoding() | should be 'Constructed' }
        it 'should have undefined length' { $asn1Type.Length | should be -1 }
        it 'should have BitString tag name' { $asn1Type.GetTagName() | should be 'BitString' }
        it 'should contain two Asn1Type values' { $asn1Type.RawValue.Count | should be 2 }
        #TODO: Asn1Type needs to parse BITSTRING values
        #Value for first component should be 0A3B
        $node = $asn1Type.RawValue.First
        $innerType = $node.Value
        context 'First Encoded Tag' {
            it 'should have BitString tag name' { $innerType.GetTagName() | should be 'BitString' }
            it 'should have first value of 000A3B' { hexBin $innerType.RawValue | should be '000A3B' }
        }
        #Value for second component should be 5F91CD
        $node = $node.Next
        $innerType = $node.Value
        context 'Second Encoded Tag' {
            it 'should have BitString tag name' { $innerType.GetTagName() | should be 'BitString' }
            it 'should have second value of 045F291CD0' { hexBin $innerType.RawValue | should be '045F291CD0' }
        }
    }
}

describe 'X.690 Example Sequence [8.9.3]' {
    $asn1Data = binHex '300A1605536D6974680101FF'
    $asn1Type = [Asn1Type]::ReadTag($asn1Data)
    context 'SEQUENCE {name IA5String, ok BOOLEAN}' {
        it 'should have tag name of Asn1Sequence' { $asn1Type.GetTagName() | should be 'Asn1Sequence' }
        it 'should have encoding of Constructed' { $asn1Type.GetEncoding() | should be 'Constructed' }
        $node = $asn1Type.RawValue.First
        context 'name IA5String' {
            $innerType = $node.Value
            it 'should have tag name of IA5String' { $innerType.GetTagName() | should be 'IA5String' }
            it 'should have value of Smith' { $innerType.ToASCIIString() | should be 'Smith' }
        }
        $node = $node.Next
        context 'ok BOOLEAN' {
            $innerType = $node.Value
            it 'should have tag name of Boolean' { $innerType.GetTagName() | should be 'Boolean' }
            it 'should have value of true' { $innerType.ToBoolean() | should be $true }
        }
    }
}

function ConstructAsn1Time([string]$DateTime, [bool]$IsUTCTime)
{
    $encodedValue = [Text.Encoding]::ASCII.GetBytes($DateTime)
    $asn1Data = [Array]::CreateInstance([byte], $encodedValue.Length + 2)
    $asn1Data[0] = if ($IsUTCTime) { 0x17 } else { 0x18 }
    $asn1Data[1] = [byte]$encodedValue.Length
    [Buffer]::BlockCopy($encodedValue, 0, $asn1Data, 2, $encodedValue.Length)
    return [Asn1Type]::ReadTag($asn1Data)
}

describe 'X.690 Example Valid GeneralizedTime Encodings [11.7]' {
    context 'Encoded value of 19920521000000Z' {
        $asn1Type = ConstructAsn1Time '19920521000000Z' $false
        $correctTime = '1992-05-21T00:00:00.0000000Z'
        it 'should have tag name of GeneralizedTime' { $asn1Type.GetTagName() | should be 'GeneralizedTime' }
        it "should have ISO date value of $correctTime" { $asn1Type.ToDateTime($false).ToString('o') | should be $correctTime }
    }
    context 'Encoded value of 19920622123421Z' {
        $asn1Type = ConstructAsn1Time '19920622123421Z' $false
        $correctTime = '1992-06-22T12:34:21.0000000Z'
        it 'should have tag name of GeneralizedTime' { $asn1Type.GetTagName() | should be 'GeneralizedTime' }
        it "should have ISO date value of $correctTime" { $asn1Type.ToDateTime($false).ToString('o') | should be $correctTime }        
    }
    context 'Encoded value of 19920722132100.3Z' {
        $asn1Type = ConstructAsn1Time '19920722132100.3Z' $false
        $correctTime = '1992-07-22T13:21:00.3000000Z'
        it 'should have tag name of GeneralizedTime' { $asn1Type.GetTagName() | should be 'GeneralizedTime' }
        it "should have ISO date value of $correctTime" { $asn1Type.ToDateTime($false).ToString('o') | should be $correctTime }        
    }
}

describe 'X.690 Example Valid UTCTime Encodings [11.8]' {
    context 'Encoded value of 920521000000Z' {
        $asn1Type = ConstructAsn1Time '920521000000Z' $true
        $correctTime = '1992-05-21T00:00:00.0000000Z'
        it 'should have tag name of UTCTime' { $asn1Type.GetTagName() | should be 'UTCTime' }
        it "should have ISO date value of $correctTime" { $asn1Type.ToDateTime($true).ToString('o') | should be $correctTime }
    }
    context 'Encoded value of 920622123421Z' {
        $asn1Type = ConstructAsn1Time '920622123421Z' $true
        $correctTime = '1992-06-22T12:34:21.0000000Z'
        it 'should have tag name of UTCTime' { $asn1Type.GetTagName() | should be 'UTCTime' }
        it "should have ISO date value of $correctTime" { $asn1Type.ToDateTime($true).ToString('o') | should be $correctTime }        
    }
    context 'Encoded value of 920722132100Z' {
        $asn1Type = ConstructAsn1Time '920722132100Z' $true
        $correctTime = '1992-07-22T13:21:00.0000000Z'
        it 'should have tag name of UTCTime' { $asn1Type.GetTagName() | should be 'UTCTime' }
        it "should have ISO date value of $correctTime" { $asn1Type.ToDateTime($true).ToString('o') | should be $correctTime }        
    }
    # In X.509 specs, values after this are considered 1900s (above tests) and values before are 2000s
    context 'Encoded value of 491231235959Z' {
        $asn1Type = ConstructAsn1Time '491231235959Z' $true
        $correctTime = '2049-12-31T23:59:59.0000000Z'
        it 'should have tag name of UTCTime' { $asn1Type.GetTagName() | should be 'UTCTime' }
        it "should have ISO date value of $correctTime" { $asn1Type.ToDateTime($true).ToString('o') | should be $correctTime }        
    }
}

describe 'X.690 Example Encoding of a Prefixed Type Value [8.14]' {
    context 'Type1 ::= VisibleString' {
        $asn1Type1 = [Asn1Type]::ReadTag((binHex '1A054A6F6E6573'))
        it 'should have tag name of VisibleString' { $asn1Type1.GetTagName() | should be 'VisibleString' }
        it 'should have value of Jones' { $asn1Type1.ToASCIIString() | should be 'Jones' }
    }
    context 'Type2 ::= [APPLICATION 3] IMPLICIT Type1' {
        $asn1Type2 = [Asn1Type]::ReadTag((binHex '43054A6F6E6573'))
        it 'should have tag name of [Application 3]' { $asn1Type2.GetTagName() | should be '[Application 3]' }
        it 'should have implicit value of Jones' { $asn1Type2.ToASCIIString() | should be 'Jones' }
    }
    context 'Type3 ::= [2] Type2' {
        $asn1Type3 = [Asn1Type]::ReadTag((binHex 'A20743054A6F6E6573'))
        it 'should have tag name of [ContextSpecific 2]' { $asn1Type3.GetTagName() | should be '[ContextSpecific 2]' }
        it 'should have encoding of Constructed' { $asn1Type3.GetEncoding() | should be 'Constructed' }
        it 'should have one encoded value' { $asn1Type3.RawValue.Count | should be 1 }
        $encodedType = $asn1Type3.RawValue.First.Value
        it 'should have encoded tag name of [Application 3]' { $encodedType.GetTagName() | should be '[Application 3]' }
        it 'should have encoded implicit value of Jones' { $encodedType.ToASCIIString() | should be 'Jones' }
    }
    context 'Type4 ::= [APPLICATION 7] IMPLICIT Type3' {
        $asn1Type4 = [Asn1Type]::ReadTag((binHex '670743054A6F6E6573'))
        it 'should have tag name of [Application 7]' { $asn1Type4.GetTagName() | should be '[Application 7]' }
        it 'should have encoding of Constructed' { $asn1Type4.GetEncoding() | should be 'Constructed' }
        it 'should have one encoded value' { $asn1Type4.RawValue.Count | should be 1 }
        $encodedType = $asn1Type4.RawValue.First.Value
        it 'should have encoded tag name of [Application 3]' { $encodedType.GetTagName() | should be '[Application 3]' }
        it 'should have encoded implicit value of Jones' { $encodedType.ToASCIIString() | should be 'Jones' }
    }
    context 'Type5 ::= [2] IMPLICIT Type2' {
        $asn1Type5 = [Asn1Type]::ReadTag((binHex '82054A6F6E6573'))
        it 'should have tag name of [ContextSpecific 2]' { $asn1Type5.GetTagName() | should be '[ContextSpecific 2]' }
        it 'should have implicit value of Jones' { $asn1Type5.ToASCIIString() | should be 'Jones' }
    }
}

describe 'X.690 Encoding of a Object Identifier Value [8.19]' {
    $asn1Data = binHex '06092A864886F70D010101'
    $asn1Type = [Asn1Type]::ReadTag($asn1Data)
    it 'should have tag name of ObjectIdentifier' { $asn1Type.GetTagName() | should be 'ObjectIdentifier' }
    it 'should have value of 1.2.840.113549.1.1.1' { $asn1Type.ToObjectIdentifier() | should be '1.2.840.113549.1.1.1' }
}

describe 'X.690 Example Record Structure [A.3]' {
    $asn1Data = [IO.MemoryStream]::new([Convert]::FromBase64String('YIGFYRAaBEpvaG4aAVAaBVNtaXRooAoaCERpcmVjdG9yQgEzoQpDCDE5NzEwOTE3ohJhEBoETWFyeRoBVBoFU21pdGijQjEfYREaBVJhbHBoGgFUGgVTbWl0aKAKQwgxOTU3MTExMTEfYREaBVN1c2FuGgFCGgVKb25lc6AKQwgxOTU5MDcxNw=='))
    $asn1Type = [Asn1Type]::ReadTagFromStream($asn1Data)
    it 'should have {name {givenName}} value of John' {
        $asn1Type.RawValue[0].RawValue[0].ToASCIIString() | should be 'John'
    }
}

describe 'Large Integer Parsing' {
    $asn1Data = [IO.MemoryStream]::new([Convert]::FromBase64String('AoGBAI/iQSoI6FGojLPoU+fVSVCzJ4ory+q1QnPqAlfMZTPuiCBhoRdWwSQY46gI077ZMfM3C5S4zEMIC3Ak95yxjV3WbYLQVAmE+J+XAXUFnInU1ckeyRPXKmswkRnW1ELgxJ18knHhsi9cje7w8Rce0l8xW7GcvCBVvzo3QkV13JBl'))
    $asn1Type = [Asn1Type]::ReadTagFromStream($asn1Data)

    it 'should have tag name of Integer' { $asn1Type.GetTagName() | should be 'Integer' }
    it 'should have length of 129' { $asn1Type.Length | should be 129 }
    it 'should have an Integer value of 101038...848421' { $asn1Type.ToInteger().ToString() | should be '101038645214968213029489864879507742420925199145132483818978980455132582258676381289000109319204510275496178360219909358646064503513889573494768497419381751359787623037449375660247011308028102339473875820259375735204357343091558075960601364303443174344509161224592926325506446708043127306053676664799729848421' }
}
