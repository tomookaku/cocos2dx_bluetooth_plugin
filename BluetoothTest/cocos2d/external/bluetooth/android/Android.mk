LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE    := cocos_bluetooth_plugin_static

LOCAL_MODULE_FILENAME := libbluetooth_plugin

LOCAL_SRC_FILES := \
	CCBluetooth.cpp \
	jni/Java_org_cocos2dx_lib_bluetooth_BluetoothManager.cpp


LOCAL_WHOLE_STATIC_LIBRARIES := cocos2dx_static

LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/../include

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../include
                    
include $(BUILD_STATIC_LIBRARY)
