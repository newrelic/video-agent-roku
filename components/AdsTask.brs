Library "Roku_Ads.brs"

sub init()
    print "AdsTask init"
    m.top.functionName = "adsTaskMain"
end sub

function adsTaskMain()
    print "AdsTaskMain function"
    
    adIface = Roku_Ads()
    
    ' Generate custom Ad Call URL for preroll (2 ads)
    adCallUrl = BuildAdCallURL("http://mobile.smartadserver.com", "213040", "901271", "29117", "roku", 1, 2, 0)
    adCallUrl = AddAdvertisingMacrosInfosToAdCallURL(adCallUrl, "SmartOnRoku")
    adCallUrl = AddRTBParametersToAdCallURL(adCallUrl, 1920, 1080, 10, 60, 200, 5000, 1, "domain.com")
    adCallUrl = AddContentDataParametersToAdCallURL(adCallUrl, "contentID", "title", "type", "category", 60, 1, 1, "rating", "providerid", "providername", "distribid", "distribname", "tag1,tag2", "external", "cms")
    adCallUrl = AddPrivacyParametersToAdCallURL(adCallUrl, "IABTCFBase64urlConsentString")

    print "AdCallURL: "; adCallUrl

    ' Set Ad call URL
    adIface.setAdUrl(adCallUrl)
    
    adPods = adIface.getAds()
    
    'print "Ad Pods = ", adPods[0]
    
    adIface.enableAdMeasurements(true)
    logObj = {
         log : Function(evtType = invalid as Dynamic, ctx = invalid as Dynamic)
                   print "------> logObj", evtType, ctx
                   if GetInterface(evtType, "ifString") <> invalid
                       print "*** tracking event " + evtType + " fired."
                       if ctx.companion = true then
                           print "***** companion = true"
                       end if
                       if ctx.errMsg <> invalid then print "*****   Error message: " + ctx.errMsg
                       if ctx.adIndex <> invalid then print "*****  Ad Index: " + ctx.adIndex.ToStr()
                       if ctx.ad <> invalid and ctx.ad.adTitle <> invalid then print "*****  Ad Title: " + ctx.ad.adTitle
                   else if ctx <> invalid and ctx.time <> invalid
                       print "*** checking tracking events for ad progress: " + ctx.time.ToStr()
                   end if
               End Function
     }
     logFunc = Function(obj = Invalid as Dynamic, evtType = invalid as Dynamic, ctx = invalid as Dynamic)
                   
                   print "logFunc m = ", m
                   print "logFunc m.top = ", m.top
                   
                   nrTrackRAF(obj, evtType)
                   
                   'obj.log(evtType, ctx)
               End Function
    
    'adIface.setTrackingCallback(logFunc, logObj)
    adIface.setTrackingCallback(logFunc, m.top.nr)
    
    shouldPlayContent = adIface.showAds(adPods, invalid, m.top.videoNode.getParent())
    
    print "SHOULD PLAY CONTENT = ", shouldPlayContent 
    
    m.top.videoNode.control = "play"
    m.top.videoNode.setFocus(true)
    
    print "END AdsTaskMain function"
end function