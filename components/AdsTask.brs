Library "Roku_Ads.brs"

sub init()
    print "AdsTask init"
    m.top.functionName = "adsTaskMain"
    m.adCount = 0
end sub

function adsTaskMain()
    print "AdsTaskMain function"
    
    adIface = Roku_Ads()
    
    ' Generate custom Ad Call URL for preroll (2 ads for testing)
    adCallUrl = BuildAdCallURL("http://mobile.smartadserver.com", "213040", "901271", "29117", "roku", 1, 2, 0)
    adCallUrl = AddAdvertisingMacrosInfosToAdCallURL(adCallUrl, "SmartOnRoku")
    adCallUrl = AddRTBParametersToAdCallURL(adCallUrl, 1920, 1080, 10, 60, 200, 5000, 1, "domain.com")
    adCallUrl = AddContentDataParametersToAdCallURL(adCallUrl, "contentID", "title", "type", "category", 60, 1, 1, "rating", "providerid", "providername", "distribid", "distribname", "tag1,tag2", "external", "cms")
    adCallUrl = AddPrivacyParametersToAdCallURL(adCallUrl, "IABTCFBase64urlConsentString")
    
    adIface.setAdUrl(adCallUrl)
 
    print "AdCallURL: "; adCallUrl
    
    adPods = adIface.getAds()
    adIface.enableAdMeasurements(true)

    logFunc = Function(obj = Invalid as Dynamic, evtType = invalid as Dynamic, ctx = invalid as Dynamic)
        print "logFunc evtType = ", evtType
        print "logFunc ctx = ", ctx
        if ctx.ad <> invalid
            print "Ad info = ", ctx.ad
        end if
        
        ' Force AD_ERROR when second ad starts to play
        if evtType = "AdStart" and m.adCount = 1
            print "*** FORCING AD_ERROR when 2nd ad starts - testing timeSinceLastAdError ***"
            
            ' Create fake error context for 2nd ad start
            errorCtx = {
                ad: ctx.ad,
                errType: "FORCED_2ND_AD_ERROR", 
                errCode: "TEST_ERROR_002",
                errMsg: "Forced error during 2nd ad start for testing timeSinceLastAdError attribute"
            }
            
            ' Call RAF tracker with AD_ERROR
            nrTrackRAF(obj, "AdError", errorCtx)
        end if
        
        ' Track ad starts to count them
        if evtType = "AdStart"
            m.adCount = m.adCount + 1
            print "Ad #" + str(m.adCount) + " started"
        end if
        
        'Call RAF tracker for normal events
        nrTrackRAF(obj, evtType, ctx)
    End Function
    
    adIface.setTrackingCallback(logFunc, m.top.nr)
    
    shouldPlayContent = adIface.showAds(adPods, invalid, m.top.videoNode.getParent())
    
    print "SHOULD PLAY CONTENT = ", shouldPlayContent 
    
    m.top.videoNode.control = "play"
    m.top.videoNode.setFocus(true)
    
    print "END AdsTaskMain function"
end function