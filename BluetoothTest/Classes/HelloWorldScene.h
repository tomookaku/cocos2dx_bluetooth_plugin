#ifndef __HELLOWORLD_SCENE_H__
#define __HELLOWORLD_SCENE_H__

#include "cocos2d.h"
#include "CCBluetooth.h"

class HelloWorld : public cocos2d::Layer,
                   public bluetooth_plugin::CCBluetoothDelegate
{
public:
    // there's no 'id' in cpp, so we recommend returning the class instance pointer
    static cocos2d::Scene* createScene();

    // Here's a difference. Method 'init' in cocos2d-x returns bool, instead of returning 'id' in cocos2d-iphone
    virtual bool init();  
    
    // a selector callback
    void menuCloseCallback(cocos2d::Ref* pSender);
    
    // implement the "static create()" method manually
    CREATE_FUNC(HelloWorld);

    void menuStartCallback(cocos2d::Ref* pSender);
    void menuStopCallback(cocos2d::Ref* pSender);

    void onResult(int resultCode, int status, const char *error, const char *peerID, const char *message);

private:
    bool _bluetooth_start;
    bluetooth_plugin::CCBluetooth *bluetooth;

};

#endif // __HELLOWORLD_SCENE_H__
