#Requires -Version 5.0

using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Numerics
using namespace System.Text

enum Asn1Class
{
    Universal = 0x00
    Application = 0x01
    ContextSpecific = 0x02
}

enum Asn1UniversalType
{
    Boolean = 0x01
    Integer = 0x02
    BitString = 0x03
    OctetString = 0x04
    Null = 0x05
    ObjectIdentifier = 0x06
    ObjectDescriptor = 0x07
    External = 0x08
    Real = 0x09
    Enumerated = 0x0A
    EmbeddedPDV = 0x0B
    UTF8String = 0x0C
    Asn1Sequence = 0x10
    Asn1Set = 0x11
    NumericString = 0x12
    PrintableString = 0x13
    TeletexString = 0x14
    VideotexString = 0x15
    IA5String = 0x16
    UTCTime = 0x17
    GeneralizedTime = 0x18
    GraphcString = 0x19
    VisibleString = 0x1A
    GeneralString = 0x1B
    UniversalString = 0x1C
    BMPString = 0x1E
}

class Asn1Type
{
    [byte]$Class = 0
    [long]$Number = 0
    [bool]$IsConstructed = $false
    [long]$Offset = 0
    [long]$Length = 0
    [object]$RawValue = $null

    [string] GetTagName()
    {
        $tagName = if ($this.Class -eq 0x00)
        {
            if ($this.Number -eq 0x00) { 'End of Content' }
            elseif ([Enum]::IsDefined([Asn1UniversalType], [int]$this.Number)) { [Asn1UniversalType]$this.Number }
            else { '[Private {0}]' -f $this.Number }
        }
        else { '[{0} {1}]' -f $this.GetClassName(), $this.Number }

        return $tagName
    }

    [string] GetClassName()
    {
        return [Asn1Class]$this.Class
    }

    [string] GetEncoding()
    {
        $encoding = if ($this.IsConstructed) { 'Constructed' } else { 'Primitive' }
        return $encoding
    }

    [void] hidden ParseIdentifierOctets([Stream]$Stream)
    {
        $this.Offset = $Stream.Position
        $firstByte = [byte]$Stream.ReadByte()

        if ($firstByte -eq 0x00)
        {
            $nextByte = [byte]$Stream.ReadByte()
            if ($nextByte -ne 0x00) { throw 'End of Content tag must be followed by a zero value octet' }
            return
        }

        $this.Class = ($firstByte -band 0xC0) -shr 6
        $this.IsConstructed = ($firstByte -band 0x20) -eq 0x20
    
        $tagNumber = [long]($firstByte -band 0x1F)
        if ($tagNumber -eq 0x1F)
        {
            $tagNumber = 0
            $nextByte = [byte]$Stream.ReadByte()
            if (($nextByte -band 0x7F) -eq 0x00) { throw 'Expected valid high tag number (X.690 8.1.2.4.2 c)' }
            do
            {
                $tagNumber += ($tagNumber -shl 7) + ($nextByte -band 0x7F)
                $nextByte = [byte]$Stream.ReadByte()
            }
            while (($nextByte -band 0x80) -eq 0x80)
            $tagNumber += ($tagNumber -shl 7) + $nextByte
        }

        $this.Number = $tagNumber
    }

    [void] hidden ParseLengthOctets([Stream]$Stream)
    {
        $tagLength = [long]0
        $firstByte = [byte]$Stream.ReadByte()

        if ($firstByte -eq 0x80) { $tagLength = [long]-1 }
        elseif ($firstByte -le 0x7F) { $tagLength = [long]$firstByte }
        else
        {
            $lengthBytes = $firstByte -band 0x7F
            for ($i = 0; $i -lt $lengthBytes; $i++)
            {
                $nextByte = [byte]$Stream.ReadByte()
                $tagLength = ($tagLength -shl 8) + $nextByte
            }
        }

        $this.Length = $tagLength
    }

    [void] hidden ParseContentOctets([Stream]$Stream)
    {
        if ($this.IsConstructed)
        {
            $contentList = [LinkedList[Asn1Type]]::new()
            $remainingLength = if ($this.Length -ne -1) { $Stream.Position + $this.Length } else { $Stream.Length }
            while ($Stream.Position -lt $remainingLength)
            {
                $nextTag = [Asn1Type]::ReadTagFromStream($Stream)
                if ($nextTag) { $contentList.Add($nextTag) } else { break }
            }
            $this.RawValue = $contentList
        }
        else
        {
            if ($this.Length -gt 0)
            {
                $buffer = [byte[]]::new($this.Length)
                $bytesRead = $Stream.Read($buffer, 0, $this.Length)
    
                if ($bytesRead -lt $buffer.Length) { throw 'Unable to read enough octets for the specified tag length' }
                $this.RawValue = $buffer
            }
        }
    }

    [Asn1Type] static ReadTag([byte[]]$Buffer)
    {
        $stream = [MemoryStream]::new($Buffer)
        return [Asn1Type]::ReadTagFromStream($stream)
    }

    [Asn1Type] static ReadTagFromStream([Stream]$Stream)
    {
        $asn1Type = New-Object Asn1Type
        $asn1Type.ParseIdentifierOctets($Stream)
        if ($asn1Type.Class -eq 0 -and $asn1Type.Number -eq 0) { return $null }
        $asn1Type.ParseLengthOctets($Stream)
        $asn1Type.ParseContentOctets($Stream)
        return $asn1Type
    }

    [void] hidden BuildDebugOutput([StringBuilder]$StringBuilder, [int]$Depth)
    {
        if ($Depth -ne 0) { [void]$StringBuilder.Append([Environment]::NewLine) }
        [void]$StringBuilder.Append([char]' ', $Depth * 2)
        [void]$StringBuilder.Append($this.GetTagName())
        if ($this.RawValue)
        {
            if ($this.IsConstructed)
            {
                foreach ($node in $this.RawValue) { $node.BuildDebugOutput($StringBuilder, $Depth + 1) }
            }
            else
            {
                [void]$StringBuilder.Append(': ')
                $out = [string]::Empty
                $printRawValue = $true

                if ($this.Class -eq 0x00)
                {
                    $printRawValue = $false
                    if ($this.Number -eq [Asn1UniversalType]::Boolean) { $out = if ($this.ToBoolean()) {'True'} else {'False'} }
                    elseif ($this.Number -eq [Asn1UniversalType]::Integer) { $out = $this.ToInteger().ToString() }
                    elseif ($this.Number -eq [Asn1UniversalType]::ObjectIdentifier) { $out = $this.ToObjectIdentifier() }
                    elseif ($this.Number -eq [Asn1UniversalType]::PrintableString) { $out = $this.ToASCIIString() }
                    elseif ($this.Number -eq [Asn1UniversalType]::GeneralString) { $out = $this.ToASCIIString() }
                    elseif ($this.Number -eq [Asn1UniversalType]::UTCTime) { $out = $this.ToDateTime($true).ToString('o') }
                    elseif ($this.Number -eq [Asn1UniversalType]::GeneralizedTime) { $out = $this.ToDateTime($false).ToString('o') }
                    elseif ($this.Number -eq [Asn1UniversalType]::UTF8String) { $out = $this.ToUTF8String() }
                    elseif ($this.Number -eq [Asn1UniversalType]::OctetString)
                    {
                        $innerStream = [MemoryStream]$this.RawValue
                        try
                        {
                            $innerTag = [Asn1Type]::ReadTagFromStream($innerStream)
                            if ($innerStream.Position -eq $innerStream.Length)
                            {
                                [void]$StringBuilder.Append('(enc)')
                                $innerTag.BuildDebugOutput($StringBuilder, $Depth + 1)
                            }
                        }
                        catch { $printRawValue = $true }
                    }
                    else { $printRawValue = $true }
                }
                if ($printRawValue)
                {
                    $this.RawValue | ForEach-Object { [void]$StringBuilder.Append($_.ToString('X2')) }
                }
                else
                {
                    [void]$StringBuilder.Append($out)
                }
            }
        }
    }

    [string] ToString()
    {
        return $this.GetTagName()
    }

    [string] ToDebugString()
    {
        $sb = New-Object Text.StringBuilder
        $this.BuildDebugOutput($sb, 0)
        return $sb.ToString()
    }

    [bool] hidden ToBoolean()
    {
        return ([byte]$this.RawValue[0] -ne 0x00)
    }

    [BigInteger] hidden ToInteger()
    {
        if ([BitConverter]::IsLittleEndian)
        {
            $reverseData = [byte[]]::new($this.Length)
            [Buffer]::BlockCopy($this.RawValue, 0, $reverseData, 0, $reverseData.Length)
            [Array]::Reverse($reverseData)
            return [BigInteger]::new($reverseData)
        }
        else
        {
            return [BigInteger]::new($this.RawValue)
        }
    }

    [string] hidden ToASCIIString()
    {
        return ([Encoding]::ASCII.GetString($this.RawValue))
    }

    [string] hidden ToUTF8String()
    {
        return ([Encoding]::UTF8.GetString($this.RawValue))
    }

    [DateTime] hidden ToDateTime([bool]$isUTCTime)
    {
        $isoTime = [Encoding]::ASCII.GetString($this.RawValue)
        if (!$isoTime.EndsWith([char]'Z')) { throw 'Encoded times must be terminated with Z' }

        $returnTime = $null
        if ($isUTCTime)
        {
            $year = [int]::Parse($isoTime.Substring(0, 2))
            if ($year -gt 49) { $year += 1900 } else { $year += 2000 }
            $month = [int]::Parse($isoTime.Substring(2, 2))
            $day = [int]::Parse($isoTime.Substring(4, 2))
            $hour = [int]::Parse($isoTime.Substring(6, 2))
            $minute = [int]::Parse($isoTime.Substring(8, 2))
            $second = [int]::Parse($isoTime.Substring(10, 2))

            $returnTime = [DateTime]::new($year, $month, $day, $hour, $minute, $second, [DateTimeKind]::Utc)
        }
        else
        {
            $year = [int]::Parse($isoTime.Substring(0, 4))
            $month = [int]::Parse($isoTime.Substring(4, 2))
            $day = [int]::Parse($isoTime.Substring(6, 2))
            $hour = [int]::Parse($isoTime.Substring(8, 2))
            $minute = [int]::Parse($isoTime.Substring(10, 2))
            $second = [int]::Parse($isoTime.Substring(12, 2))
            $millisecond = 0

            if ($isoTime.Length -gt 15)
            {
                $remainder = [double]::Parse('0.'+$isoTime.Substring(14, $isoTime.Length - 15).TrimStart([char]'.'))
                $millisecond = [int][Math]::Floor($remainder * 1000)
            }

            $returnTime = [DateTime]::new($year, $month, $day, $hour, $minute, $second, $millisecond, [DateTimeKind]::Utc)
        }
        return $returnTime
    }

    [string] hidden ToObjectIdentifier()
    {
        $byte = [byte]$this.RawValue[0]
        $sb = New-Object StringBuilder
        [void]$sb.AppendFormat('{0}.{1}', [int]($byte / 40), [int]($byte % 40))

        $subid = New-Object BigInteger 0
        for ($i = 1; $i -lt $this.RawValue.Length; ++$i)
        {
            $byte = $this.RawValue[$i]
            if (($byte -band 0x80) -eq 0x80)
            {
                $subid = ($subid -shl 7) + ($byte -band 0x7F)
            }
            else
            {
                $subid = ($subid -shl 7) + $byte
                [void]$sb.AppendFormat('.{0}', $subid.ToString())
                $subid = New-Object BigInteger 0
            }
        }

        return $sb.ToString()
    }
}
