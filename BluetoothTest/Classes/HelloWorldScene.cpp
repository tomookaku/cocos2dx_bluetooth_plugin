#include "HelloWorldScene.h"

USING_NS_CC;

Scene* HelloWorld::createScene()
{
    // 'scene' is an autorelease object
    auto scene = Scene::create();
    
    // 'layer' is an autorelease object
    auto layer = HelloWorld::create();

    // add layer as a child to scene
    scene->addChild(layer);

    // return the scene
    return scene;
}

// on "init" you need to initialize your instance
bool HelloWorld::init()
{
    //////////////////////////////
    // 1. super init first
    if ( !Layer::init() )
    {
        return false;
    }
    
    Size visibleSize = Director::getInstance()->getVisibleSize();
    Vec2 origin = Director::getInstance()->getVisibleOrigin();

    /////////////////////////////
    // 2. add a menu item with "X" image, which is clicked to quit the program
    //    you may modify it.

    auto startItem = MenuItemImage::create(
                                           "start.png",
                                           "start.png",
                                           CC_CALLBACK_1(HelloWorld::menuStartCallback, this));
    
	startItem->setPosition(Point(origin.x + visibleSize.width - startItem->getContentSize().width/2 - 200,
                                origin.y + startItem->getContentSize().height/2));

    auto stopItem = MenuItemImage::create(
                                           "stop.png",
                                           "stop.png",
                                           CC_CALLBACK_1(HelloWorld::menuStopCallback, this));
    
	stopItem->setPosition(Point(origin.x + visibleSize.width - stopItem->getContentSize().width/2 - 80,
                                 origin.y + stopItem->getContentSize().height/2));
    
    // add a "close" icon to exit the progress. it's an autorelease object
    auto closeItem = MenuItemImage::create(
                                           "CloseNormal.png",
                                           "CloseSelected.png",
                                           CC_CALLBACK_1(HelloWorld::menuCloseCallback, this));
    
	closeItem->setPosition(Vec2(origin.x + visibleSize.width - closeItem->getContentSize().width/2 ,
                                origin.y + closeItem->getContentSize().height/2));

    // create menu, it's an autorelease object
    auto menu = Menu::create(startItem, stopItem, closeItem, NULL);
    menu->setPosition(Vec2::ZERO);
    this->addChild(menu, 1);

    /////////////////////////////
    // 3. add your codes below...

    // add a label shows "Hello World"
    // create and initialize a label
    
    auto label = LabelTTF::create("Hello World", "Arial", 24);
    
    // position the label on the center of the screen
    label->setPosition(Vec2(origin.x + visibleSize.width/2,
                            origin.y + visibleSize.height - label->getContentSize().height));

    // add the label as a child to this layer
    this->addChild(label, 1);

    // add "HelloWorld" splash screen"
    auto sprite = Sprite::create("HelloWorld.png");

    // position the sprite on the center of the screen
    sprite->setPosition(Vec2(visibleSize.width/2 + origin.x, visibleSize.height/2 + origin.y));

    // add the sprite as a child to this layer
    this->addChild(sprite, 0);
    
    _bluetooth_start = false;

    return true;
}

void HelloWorld::onResult(int resultCode, int status, const char *error, const char *peerID, const char *message)
{
    CCLOG("onResult resultCode: %d", resultCode);
    CCLOG("onResult status: %d", status);
    CCLOG("onResult error: %s", error);
    CCLOG("onResult peerID: %s", peerID);
    CCLOG("onResult message: %s", message);

	if (resultCode != RESULT_RECEIVE_MESSAGE || status != STATUS_OK) {
	    if (_bluetooth_start) {
    	    _bluetooth_start = false;

        	bluetooth->stop();
    	}
	}
}

void HelloWorld::menuStartCallback(Ref* pSender)
{
    if (!_bluetooth_start) {
        _bluetooth_start = true;

        bluetooth = new bluetooth_plugin::CCBluetooth(this);
        
		std::stringstream ss;
		ss << time(NULL);
		std::string str = ss.str();

        std::string peerID = "peer-" + str;
        std::string message = "Hello form " + peerID;
        
        CCLOG("peerID: %s", peerID.c_str());
        CCLOG("message: %s", message.c_str());
        
        bluetooth->start(peerID.c_str(), message.c_str());
    }
}

void HelloWorld::menuStopCallback(Ref* pSender)
{
    if (_bluetooth_start) {
        _bluetooth_start = false;

        bluetooth->stop();
    }
}

void HelloWorld::menuCloseCallback(Ref* pSender)
{
#if (CC_TARGET_PLATFORM == CC_PLATFORM_WP8) || (CC_TARGET_PLATFORM == CC_PLATFORM_WINRT)
	MessageBox("You pressed the close button. Windows Store Apps do not implement a close button.","Alert");
    return;
#endif

    Director::getInstance()->end();

#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    exit(0);
#endif
}
