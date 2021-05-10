Library "Roku_Ads.brs"
Library "IMA3.brs"
    
sub init()
  m.top.functionName = "runThread"
End Sub

sub runThread()
  if not m.top.sdkLoaded
    loadSdk()
  End If
  if not m.top.streamManagerReady
    loadStream()
  End If
  If m.top.streamManagerReady
    runLoop()
  End If
End Sub

sub loadSdk()
    If m.sdk = invalid
      m.sdk = New_IMASDK()
    End If
    m.top.sdkLoaded = true
End Sub

sub setupVideoPlayer()
  sdk = m.sdk
  m.player = sdk.createPlayer()
  m.player.top = m.top
  m.player.loadUrl = Function(urlData)
    m.top.video.enableTrickPlay = false
    m.top.urlData = urlData
  End Function
  m.player.adBreakStarted = Function(adBreakInfo as Object)
    print "---- Ad Break Started ---- ", adBreakInfo
    m.top.adPlaying = True
    m.top.video.enableTrickPlay = false
    
    sendIMAAdBreakStart(adBreakInfo)
  End Function
  m.player.adBreakEnded = Function(adBreakInfo as Object)
    print "---- Ad Break Ended ---- ", adBreakInfo
    m.top.adPlaying = False
    m.top.video.enableTrickPlay = true
    
    sendIMAAdBreakEnd(adBreakInfo)
  End Function
End Sub

Sub loadStream()
  sdk = m.sdk
  sdk.initSdk()
  setupVideoPlayer()
  request = sdk.CreateStreamRequest()
  if m.top.streamData.type = "live"
    request.assetKey = m.top.streamData.assetKey
  else
    request.contentSourceId = m.top.streamData.contentSourceId
    request.videoId = m.top.streamData.videoId
  end if
  request.apiKey = m.top.streamData.apiKey
  request.player = m.player

  requestResult = sdk.requestStream(request)
  If requestResult <> Invalid
    print "Error requesting stream ";requestResult
  Else
    m.streamManager = Invalid
    While m.streamManager = Invalid
      sleep(50)
      m.streamManager = sdk.getStreamManager()
    End While
    If m.streamManager = Invalid or m.streamManager["type"] <> Invalid or m.streamManager["type"] = "error"
      errors = CreateObject("roArray", 1, True)
      print "error ";m.streamManager["info"]
      errors.push(m.streamManager["info"])
      m.top.errors = errors
    Else
      m.top.streamManagerReady = True
      addCallbacks()
      m.streamManager.start()
    End If
  End If
End Sub

Sub runLoop()
  m.top.video.timedMetaDataSelectionKeys = ["*"]

  m.port = CreateObject("roMessagePort")

  ' Listen to all fields.

  ' IMPORTANT: Failure to listen to the position and timedmetadata fields
  ' could result in ad impressions not being reported.
  fields = m.top.video.getFields()
  for each field in fields
    m.top.video.observeField(field, m.port)
  end for

  while True
    msg = wait(1000, m.port)
    if m.top.video = invalid
      print "exiting"
      exit while
    end if

    m.streamManager.onMessage(msg)
    currentTime = m.top.video.position
    If currentTime > 3 And not m.top.adPlaying
       m.top.video.enableTrickPlay = true
    End If
  end while
End Sub

Function addCallbacks() as Void
  m.streamManager.addEventListener(m.sdk.AdEvent.ERROR, errorCallback)
  m.streamManager.addEventListener(m.sdk.AdEvent.START, startCallback)
  m.streamManager.addEventListener(m.sdk.AdEvent.FIRST_QUARTILE, firstQuartileCallback)
  m.streamManager.addEventListener(m.sdk.AdEvent.MIDPOINT, midpointCallback)
  m.streamManager.addEventListener(m.sdk.AdEvent.THIRD_QUARTILE, thirdQuartileCallback)
  m.streamManager.addEventListener(m.sdk.AdEvent.COMPLETE, completeCallback)
End Function

'TODO:
' - Put the IMA tracker in a SG Object, independent of the NRAgent (takes an NRAgent reference)
' - Check out the initial PAUSE-RESUME evenets when an AD_BREAK starts

Function startCallback(ad as Object) as Void
  print "Callback from SDK -- Start called - ", ad.adBreakInfo, ad
  
  sendIMAAdStart(ad)
End Function

Function firstQuartileCallback(ad as Object) as Void
  print "Callback from SDK -- First quartile called - ", ad.adBreakInfo, ad
  
  sendIMAAdQuartile(ad, 1)
End Function

Function midpointCallback(ad as Object) as Void
  print "Callback from SDK -- Midpoint called - "
  
  sendIMAAdQuartile(ad, 2)
End Function

Function thirdQuartileCallback(ad as Object) as Void
  print "Callback from SDK -- Third quartile called - ", ad.adBreakInfo, ad
  
  sendIMAAdQuartile(ad, 3)
End Function

Function completeCallback(ad as Object) as Void
  print "Callback from SDK -- Complete called - ", ad.adBreakInfo, ad
  
  sendIMAAdEnd(ad)
End Function

Function errorCallback(error as Object) as Void
  print "Callback from SDK -- Error called - "; error
  m.errorState = True
  
  'TODO: send error
End Function

function nrIMAAttributes(adBreakInfo as Object, ad as Object) as Object
    attr = {}
    if adBreakInfo.podindex = 0 then attr.AddReplace("adPosition", "pre")
    if adBreakInfo.podindex > 0 then attr.AddReplace("adPosition", "mid")
    if adBreakInfo.podindex < 0 then attr.AddReplace("adPosition", "live")
    attr.AddReplace("contentPosition", adBreakInfo.timeoffset * 1000)
    
    if ad <> invalid
        attr.AddReplace("adDuration", ad.duration * 1000)
        attr.AddReplace("adId", ad.adid)
        attr.AddReplace("adTitle", ad.adtitle)
        attr.AddReplace("adSystem", ad.adsystem)
    end if
    return attr
end function

function sendIMAAdBreakStart(adBreakInfo as Object) as Void
    nrSendVideoEvent(m.top.nr, "AD_BREAK_START", nrIMAAttributes(adBreakInfo, invalid))
end function

function sendIMAAdBreakEnd(adBreakInfo as Object) as Void
    nrSendVideoEvent(m.top.nr, "AD_BREAK_END", nrIMAAttributes(adBreakInfo, invalid))
end function

function sendIMAAdStart(ad as Object) as Void
    nrSendVideoEvent(m.top.nr, "AD_START", nrIMAAttributes(ad.adBreakInfo, ad))
end function

function sendIMAAdEnd(ad as Object) as Void
    nrSendVideoEvent(m.top.nr, "AD_END", nrIMAAttributes(ad.adBreakInfo, ad))
end function

function sendIMAAdQuartile(ad as Object, quartile as Integer) as Void
    attr = nrIMAAttributes(ad.adBreakInfo, ad)
    attr.AddReplace("adQuartile", quartile)
    nrSendVideoEvent(m.top.nr, "AD_QUARTILE", attr)
end function
