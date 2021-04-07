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
    else
        print "SHOULD PLAY CONTENT FALSE"
    end if
    
    'port = CreateObject("roMessagePort")
    'while true
    '    msg = wait(0, port)
    'end while
    
    print "END AdsTaskMain function"
end function