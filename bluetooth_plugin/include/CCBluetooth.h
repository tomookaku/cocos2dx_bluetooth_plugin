#ifndef __CC_BLUETOOTH_H__
#define __CC_BLUETOOTH_H__

#include <string>
#include "cocos2d.h"

#define USING_NS_CC_BLUETOOTH  using namespace bluetooth_plugin

#define RESULT_NOTFOUND_PEER 0
#define RESULT_RECEIVE_MESSAGE 1

#define STATUS_ERROR -1
#define STATUS_OK 1

namespace bluetooth_plugin {
    
    class CCBluetooth;
    
    class CCBluetoothDelegate
    {
	public:
		virtual void onResult(int resultCode, int status, const char *error, const char *peerID, const char *message) {};
    };
    
    class CCBluetooth
    {
	public:
        CCBluetooth(CCBluetoothDelegate* delegate);
        ~CCBluetooth();
        
        void start(const char *peerID, const char *message);
        void stop();
        
    private:
        CCBluetoothDelegate* _delegate;
        
    };
    
} // End of namespace bluetooth_plugin

#endif
