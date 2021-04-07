Library "Roku_Ads.brs"

sub init()
    m.top.functionName = "adsTaskMain"
end sub

function adsTaskMain()
    print "AdsTaskMain function"
    
    adIface = Roku_Ads()
    adPods = adIface.getAds()
    adIface.enableAdMeasurements(true)
    shouldPlayContent = adIface.showAds(adPods, invalid, m.top.videoNode.getParent())
    
    if shouldPlayContent
        print "SHOULD PLAY CONTENT"
        
        m.top.videoNode.control = "play"
        m.top.videoNode.setFocus(true)
    else
        print "SHOULD PLAY CONTENT FALSE"
    end if
    
    print "END AdsTaskMain function"
end function