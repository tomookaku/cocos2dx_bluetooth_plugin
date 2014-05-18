#include "CCBluetooth.h"
#include "jni/Java_org_cocos2dx_lib_bluetooth_BluetoothManager.h"

namespace bluetooth_plugin {

static jobject _obj;

CCBluetooth::CCBluetooth(CCBluetoothDelegate* delegate)
{
	setDelegateJni(delegate);
}

CCBluetooth::~CCBluetooth()
{
	stopJni();
}

void CCBluetooth::start(const char *peerID, const char *message)
{
	startJni(peerID, message);
}

void CCBluetooth::stop()
{
	stopJni();
}

} // End of namespae bluetooth_plugin
