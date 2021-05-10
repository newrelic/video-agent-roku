REM ******************************************************
REM Generate the AdCallURL from various parameters
REM - baseURL: the baseURL for the ad call, without the ending "/"
REM - siteID: the siteID of your placement
REM - pageID: the pageID of your placement
REM - formatID: the formatID of your placement
REM - targeting: the targeting string for the call
REM - adbreaktype: the current ad break type (1 for preroll, 2 for midroll, 3 for postroll)
REM - nbInstances: the number of ads to be returned in the AdPod
REM - nbPassbacks: the number of passback linear ads to be supplied with the response.
REM ******************************************************

Function BuildAdCallURL(baseURL as String, siteID as String, pageID as String, formatID as String, targeting as String, adbreaktype as Integer, nbInstances as Integer, nbPassbacks as Integer) As String
    adCallURL = baseURL

    ' Append function parameters
    ' SiteID
    adCallURL = adCallURL + "/ac?" + "siteid=" + siteID
    ' PageID
    adCallURL = adCallURL + "&" + "pgid=" + pageID
    ' FormatID
    adCallURL = adCallURL + "&" + "fmtid=" + formatID
    ' Targeting
    adCallURL = adCallURL + "&" + "tgt=" + targeting
    ' Adbreaktype
    adCallURL = adCallURL + "&" + "ab=" + adbreaktype.ToStr()
    ' Instances
    adCallURL = adCallURL + "&" + "ps=" + nbInstances.ToStr()
    ' Passbacks
    adCallURL = adCallURL + "&" + "pb=" + nbPassbacks.ToStr()

    ' Append mandatory parameters
    ' One call: oc=1
    adCallURL = adCallURL + "&oc=1"
    ' Output: out=vast3
    adCallURL = adCallURL + "&out=vast3"
    ' Visit: visit=M for master
    adCallURL = adCallURL + "&visit=M"
    ' No ad counting: vcn=s for server side
    adCallURL = adCallURL + "&vcn=s"
    ' Flash
    adCallURL = adCallURL + "&vaf=0"
    ' Timestamp: tmstp=timestamp
    dt = createObject("roDateTime")
    timestamp = dt.AsSeconds().ToStr()
    adCallURL = adCallURL + "&" + "tmstp=" + timestamp

    ' You can also append non mandatory parameters such as:
    ' - RTB Params: vpw, vph, vdmin, vdmax, vbrmin, vbrmax, vpmt...
    ' - Content Datas Parameters...
    ' Use the 2 functions below to do so
    ' See complete documentation for more informations

    return adCallURL

End Function

REM ******************************************************
REM Add Advertising informations to the Ad call URL
REM - adCallURL: the URL you got from the previous function BuildAdCallURL()
REM - appName: the name of your application / channel
REM ******************************************************

Function AddAdvertisingMacrosInfosToAdCallURL(adCallURL as String, appName as String) As String
    advertisingInfoAdCallURL = adCallURL

    ' Append function parameters
    ' appID for bundle id
    advertisingInfoAdCallURL = advertisingInfoAdCallURL + "&buid=ROKU_ADS_APP_ID" 
    ' appID for appname
    advertisingInfoAdCallURL = advertisingInfoAdCallURL + "&appname=" + appName 
    ' trackingID
    advertisingInfoAdCallURL = advertisingInfoAdCallURL + "&uid=ROKU_ADS_TRACKING_ID" 

    return advertisingInfoAdCallURL

End Function


REM ***************************************************************
REM Add RTB ad calls parameters to a previously generated AdCallURL
REM - adCallURL: the URL you got from the previous function BuildAdCallURL()
REM - playerWidth: the width of the video player in pixels
REM - playerHeight: the height of the video player in pixels
REM - durationMin: the minimum duration of a single ad
REM - durationMax: the maximum duration of a single ad
REM - bitrateMin: the minimum bitrate of a single ad
REM - bitrateMax: the maximum bitrate of a single ad
REM - videoPlaybackMethod: the video playback method  (1 Autoplay (sound on), 2 Autoplay (sound off))
REM - pageDomain: the name of your website
REM ***************************************************************

Function AddRTBParametersToAdCallURL(adCallURL as String, playerWidth as Integer, playerHeight as Integer, durationMin as Integer, durationMax as Integer, bitrateMin as Integer, bitrateMax as Integer, videoPlaybackMethod as Integer, pageDomain as string) As String
    rtbAdCallURL = adCallURL

    ' Append function parameters
    ' playerWidth
    rtbAdCallURL = rtbAdCallURL + "&" + "vpw=" + playerWidth.ToStr()
    ' playerHeight
    rtbAdCallURL = rtbAdCallURL + "&" + "vph=" + playerHeight.ToStr()
    ' durationMin
    rtbAdCallURL = rtbAdCallURL + "&" + "vdmin=" + durationMin.ToStr()
    ' durationMax
    rtbAdCallURL = rtbAdCallURL + "&" + "vdmax=" + durationMax.ToStr()
    ' bitrateMin
    rtbAdCallURL = rtbAdCallURL + "&" + "vbrmin=" + bitrateMin.ToStr()
    ' bitrateMax
    rtbAdCallURL = rtbAdCallURL + "&" + "vbrmax=" + bitrateMax.ToStr()
    ' videoPlaybackMethod
    rtbAdCallURL = rtbAdCallURL + "&" + "vpmt=" + videoPlaybackMethod.ToStr()
    ' pageDomain
    rtbAdCallURL = rtbAdCallURL + "&" + "pgDomain=" + pageDomain

    return rtbAdCallURL

End Function


REM ****************************************************************
REM Add Content Data parameters to a previously generated AdCallURL
REM - adCallURL: the URL you got from the previous function BuildAdCallURL()
REM - contentID: the content ID. Used for syndication purpose
REM - contentTitle: name of the content video
REM - contentType: type of the content video
REM - contentCategory: category of the content video
REM - contentDuration: duration of the content video in seconds
REM - contentSeasonNumber: season number of the content video
REM - contentEpisodeNumber: episode number of the content video
REM - contentRating: permissible audience of the content video
REM - contentProviderID: identifier of the content provider
REM - contentProviderName: name of the content provider
REM - contentDistributorID: identifier of the content distributor
REM - contentDistributorName: name of the content distributor
REM - contentTags: multiple value keywords describing the video content (separated by comma)
REM - externalContentID: ddentifier of the content in a 3rd party system
REM - videoCMSID: identifier of the video content management system in charge of the content
REM ****************************************************************

Function AddContentDataParametersToAdCallURL(adCallURL as String, contentID as String, contentTitle as String, contentType as String, contentCategory as String, contentDuration as Integer, contentSeasonNumber as Integer, contentEpisodeNumber as Integer, contentRating as String, contentProviderID as String, contentProviderName as String, contentDistributorID as String, contentDistributorName as String, contentTags as String, externalContentID as String, videoCMSID as String) As String
    contentDataAdCallURL = adCallURL

    ' Append function parameters
    ' contentID
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctid=" + contentID
    ' contentTitle
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctn=" + contentTitle
    ' contentType
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctt=" + contentType
    ' contentCategory
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctc=" + contentCategory
    ' contentDuration
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctd=" + contentDuration.ToStr()
    ' contentSeasonNumber
    contentDataAdCallURL = contentDataAdCallURL + "&" + "cts=" + contentSeasonNumber.ToStr()
    ' contentEpisodeNumber
    contentDataAdCallURL = contentDataAdCallURL + "&" + "cte=" + contentEpisodeNumber.ToStr()
    ' contentRating
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctr=" + contentRating
    ' contentProviderID
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctpid=" + contentProviderID
    ' contentProviderName
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctp=" + contentProviderName
    ' contentDistributorID
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctdid=" + contentDistributorID
    ' contentDistributorName
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctdn=" + contentDistributorName
    ' contentTags
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctk=" + contentTags
    ' externalContentID
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctxid=" + externalContentID
    ' videoCMSID
    contentDataAdCallURL = contentDataAdCallURL + "&" + "ctmsid=" + videoCMSID

    return contentDataAdCallURL

End Function


REM ****************************************************************
REM Add Privacy parameters to a previously generated AdCallURL
REM - adCallURL: the URL you got from the previous function BuildAdCallURL()
REM - gdprConsentString: the base64url encoded consent string conform to IAB Transparency and Consent Framework specifications.
REM ****************************************************************

Function AddPrivacyParametersToAdCallURL(adCallURL as String, gdprConsentString as String) As String
    privacyAdCallURL = adCallURL

    ' Append function parameters
    ' gdprConsentString
    privacyAdCallURL = privacyAdCallURL + "&" + "gdpr_consent=" + gdprConsentString
    
    return privacyAdCallURL

End Function

