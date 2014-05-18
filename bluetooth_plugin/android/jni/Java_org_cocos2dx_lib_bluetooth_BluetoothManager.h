#ifndef __Java_org_cocos2dx_lib_BluetoothManager_H__
#define __Java_org_cocos2dx_lib_BluetoothManager_H__

#include <string.h>
#include <jni.h>

extern "C"
{
	void setDelegateJni(void *delegate);
	void startJni(const char *peerID, const char *message);
	void stopJni();
}
#endif
