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
    
    'Send AD_BREAK_START
    nrSendIMAAdBreakStart(m.top.tracker, adBreakInfo)
  End Function
  m.player.adBreakEnded = Function(adBreakInfo as Object)
    print "---- Ad Break Ended ---- ", adBreakInfo
    m.top.adPlaying = False
    m.top.video.enableTrickPlay = true
    
    'Send AD_BREAK_END
    nrSendIMAAdBreakEnd(m.top.tracker, adBreakInfo)
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

Function startCallback(ad as Object) as Void
  print "Callback from SDK -- Start called - ", ad.adBreakInfo, ad
  
  'Send AD_START
  nrSendIMAAdStart(m.top.tracker, ad)
End Function

Function firstQuartileCallback(ad as Object) as Void
  print "Callback from SDK -- First quartile called - ", ad.adBreakInfo, ad
  
  'Send AD_QUARTILE (first)
  nrSendIMAAdFirstQuartile(m.top.tracker, ad)
End Function

Function midpointCallback(ad as Object) as Void
  print "Callback from SDK -- Midpoint called - ", ad.adBreakInfo, ad
  
  'Send AD_QUARTILE (midpoint)
  nrSendIMAAdMidpoint(m.top.tracker, ad)
End Function

Function thirdQuartileCallback(ad as Object) as Void
  print "Callback from SDK -- Third quartile called - ", ad.adBreakInfo, ad
  
  'Send AD_QUARTILE (third)
  nrSendIMAAdThirdQuartile(m.top.tracker, ad)
End Function

Function completeCallback(ad as Object) as Void
  print "Callback from SDK -- Complete called - ", ad.adBreakInfo, ad
  
  'Send AD_END
  nrSendIMAAdEnd(m.top.tracker, ad)
End Function

Function errorCallback(error as Object) as Void
  print "Callback from SDK -- Error called - "; error
  m.errorState = True
  
  nrSendIMAAdError(m.top.tracker, error)
End Function
