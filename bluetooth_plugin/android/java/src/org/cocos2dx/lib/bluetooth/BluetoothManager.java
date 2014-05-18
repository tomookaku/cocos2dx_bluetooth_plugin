package org.cocos2dx.lib.bluetooth;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.widget.Toast;

import java.util.Timer;
import java.util.TimerTask;

import org.cocos2dx.lib.Cocos2dxActivity;

/**
 * This is the main Activity that displays the current chat session.
 */
public class BluetoothManager extends Cocos2dxActivity {
    // Debugging
    private static final String TAG = "BluetoothManager";
    private static final boolean D = true;

    // Message types sent from the BluetoothService Handler
    public static final int MESSAGE_STATE_CHANGE = 1;
    public static final int MESSAGE_READ = 2;
    public static final int MESSAGE_WRITE = 3;
    public static final int MESSAGE_DEVICE_NAME = 4;
    public static final int MESSAGE_TOAST = 5;

    // Key names received from the BluetoothService Handler
    public static final String EXTRA_DEVICE_ADDRESS = "device_address";
    public static final String DEVICE_NAME = "device_name";
    public static final String TOAST = "toast";

    // Intent request codes
    private static final int REQUEST_DISCOVERABLE = 1;
    private static final int REQUEST_CONNECT_DEVICE_INSECURE = 2;
    private static final int REQUEST_ENABLE_BT = 3;

    // Return Intent extra
    private static final int RESULT_NOTFOUND_PEER = 0;
    private static final int RESULT_RECEIVE_MESSAGE = 1;

    private static final int STATUS_ERROR = -1;
    private static final int STATUS_OK = 1;

    // Name of the connected device
    private static String mConnectedDeviceName = null;
    // Local Bluetooth adapter
    private static BluetoothAdapter mBluetoothAdapter = null;
    // Member object for the services
    private static BluetoothService mBluetoothService = null;

    private static String mBluetoothName = null;
    private static String mPeerID = null;
    private static String mMessage = null;

    private static boolean mFound = false;

    private static long mDelegate;

    private static Activity mContext;
    
    public static native void nativeCalledFromBluetoothManager(long delegate, int request, int result, String peerID, String message);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if(D) Log.e(TAG, "+++ ON CREATE +++");
        
        mContext = this;
    }

    @Override
    public void onStart() {
        super.onStart();
        if(D) Log.e(TAG, "++ ON START ++");
    }

    @Override
    public synchronized void onResume() {
        super.onResume();
        if(D) Log.e(TAG, "+ ON RESUME +");
    }

    @Override
    public synchronized void onPause() {
        super.onPause();
        if(D) Log.e(TAG, "- ON PAUSE -");
    }

    @Override
    public void onStop() {
        super.onStop();
        if(D) Log.e(TAG, "-- ON STOP --");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if(D) Log.e(TAG, "-- ON DESTROY --");
		stop();
    }

	public static void setDelegate(final long delegate) {
		mDelegate = delegate;
        Log.d(TAG, "setDelegate()");
	}

	public static void start(String peerID, String message) {
        Log.d(TAG, "start()");
        Log.d(TAG, " > peerID: " + peerID);
        Log.d(TAG, " > message: " + message);

        // Get local Bluetooth adapter
        mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();

        // If the adapter is null, then Bluetooth is not supported
        if (mBluetoothAdapter == null) {
            Toast.makeText(mContext, "Bluetooth is not available", Toast.LENGTH_LONG).show();
            return;
        }

		mPeerID = peerID;
		mMessage = message;

    	mBluetoothName = mBluetoothAdapter.getName();
    	if (mBluetoothName == null) mBluetoothName = android.os.Build.MODEL;
    	if (!mBluetoothName.startsWith(BluetoothService.NAME_INSECURE)) {
        	mBluetoothName = BluetoothService.NAME_INSECURE + ":" + mBluetoothName;
    		mBluetoothAdapter.setName(mBluetoothName);
    	}

        // Register for broadcasts when a device is discovered
        IntentFilter filter = new IntentFilter(BluetoothDevice.ACTION_FOUND);
        mContext.registerReceiver(mReceiver, filter);

        // Register for broadcasts when discovery has finished
        filter = new IntentFilter(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
        mContext.registerReceiver(mReceiver, filter);

        // Get the local Bluetooth adapter
        mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();

        // If BT is not on, request that it be enabled.
        // setupChat() will then be called during onActivityResult
        if (!mBluetoothAdapter.isEnabled()) {
            Intent enableIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            mContext.startActivityForResult(enableIntent, REQUEST_ENABLE_BT);
        // Otherwise, setup the chat session
        } else {
            if (mBluetoothService == null) setupChat();
        }

        // Performing this check in onResume() covers the case in which BT was
        // not enabled during onStart(), so we were paused to enable it...
        // onResume() will be called when ACTION_REQUEST_ENABLE activity returns.
        if (mBluetoothService != null) {
            // Only if the state is STATE_NONE, do we know that we haven't started already
            if (mBluetoothService.getState() == BluetoothService.STATE_NONE) {
              // Start the Bluetooth chat services
              mBluetoothService.start();
              if(D) Log.e(TAG, "= mBluetoothService.start() =");
            }
        }

        ensureDiscoverable(300);
	}
	
	public static void stop() {
        Log.d(TAG, "stop()");

        // Unregister broadcast listeners
        mContext.unregisterReceiver(mReceiver);

        // Stop the Bluetooth chat services
        if (mBluetoothService != null) {
        	mBluetoothService.stop();
        	mBluetoothService = null;
        }

        // Make sure we're not doing discovery anymore
        if (mBluetoothAdapter != null) {
            mBluetoothAdapter.cancelDiscovery();

	        if (mBluetoothName != null) {
		    	mBluetoothAdapter.setName(mBluetoothName);
	    		mBluetoothName = null;
        	}

            mBluetoothAdapter = null;
        }
	}

    private static void setupChat() {
        Log.d(TAG, "setupChat()");

        // Initialize the BluetoothService to perform bluetooth connections
        mBluetoothService = new BluetoothService(mContext, mHandler);
    }

    private static void ensureDiscoverable(int duration) {
        if(D) Log.d(TAG, "ensure discoverable: " + mBluetoothAdapter.getScanMode());
        if (mBluetoothAdapter.getScanMode() !=
            BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE) {
        	Intent discoverableIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE);
            discoverableIntent.putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, duration);
            mContext.startActivityForResult(discoverableIntent, REQUEST_DISCOVERABLE);
        }
        else {
            doDiscovery();
        }
    }

    /**
     * Sends a message.
     * @param message  A string of text to send.
     */
    public static void sendMessage(String message) {
        // Check that we're actually connected before trying anything
        if (mBluetoothService.getState() != BluetoothService.STATE_CONNECTED) {
            return;
        }

        // Check that there's actually something to send
        if (message.length() > 0) {
			message = mPeerID + ":" + message;

            // Get the message bytes and tell the BluetoothService to write
            byte[] send = message.getBytes();
            mBluetoothService.write(send);
        }
    }

    // The Handler that gets information back from the BluetoothService
    private static final Handler mHandler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            if(D) Log.i(TAG, "msg.what: " + msg.what);
            if(D) Log.i(TAG, "msg.arg1: " + msg.arg1);
            switch (msg.what) {
            case MESSAGE_STATE_CHANGE:
                if(D) Log.i(TAG, "MESSAGE_STATE_CHANGE: " + msg.arg1);
                switch (msg.arg1) {
                case BluetoothService.STATE_CONNECTED:
					BluetoothManager.sendMessage(mMessage);
                    break;
                case BluetoothService.STATE_CONNECTING:
                    break;
                case BluetoothService.STATE_LISTEN:
                case BluetoothService.STATE_NONE:
                    break;
                }
                break;
            case MESSAGE_WRITE:
                byte[] writeBuf = (byte[]) msg.obj;
                // construct a string from the buffer
                String writeMessage = new String(writeBuf);
                break;
            case MESSAGE_READ:
                byte[] readBuf = (byte[]) msg.obj;
                // construct a string from the valid bytes in the buffer
                final String readMessage = new String(readBuf, 0, msg.arg1);
                
				mContext.runOnUiThread(new Runnable() {
					public void run() {
		               	String peerID = "";
		               	String message = "";
        		        if (readMessage.indexOf(':') >= 0) {                
                			peerID = readMessage.substring(0, readMessage.indexOf(':'));
                			message = readMessage.substring(readMessage.indexOf(':')+1);
                		}
                
	    				BluetoothManager.nativeCalledFromBluetoothManager(mDelegate, RESULT_RECEIVE_MESSAGE, STATUS_OK, "", peerID, message);
					}
				});
                break;
            case MESSAGE_DEVICE_NAME:
                // save the connected device's name
                mConnectedDeviceName = msg.getData().getString(DEVICE_NAME);
                Toast.makeText(mContext, "Connected to "
                               + mConnectedDeviceName, Toast.LENGTH_SHORT).show();
                break;
            case MESSAGE_TOAST:
                Toast.makeText(mContext, msg.getData().getString(TOAST),
                               Toast.LENGTH_SHORT).show();
                break;
            }
        }
    };

    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if(D) Log.d(TAG, "onActivityResult " + resultCode);
        switch (requestCode) {
        case REQUEST_ENABLE_BT:
            // When the request to enable Bluetooth returns
            if (resultCode == Activity.RESULT_OK) {
                // Bluetooth is now enabled, so set up a chat session
                setupChat();
            } else {
                // User did not enable Bluetooth or an error occured
                Log.d(TAG, "BT not enabled");
            }
            break;
        case REQUEST_DISCOVERABLE:
            {
                if (resultCode != Activity.RESULT_CANCELED) {
                    final Timer timer = new Timer();
                    timer.schedule(new TimerTask() {
                        @Override
                        public void run() {
                            if (mBluetoothAdapter.getScanMode() == BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE) {
                                timer.cancel();
                                doDiscovery();
                            }
                        }
                    }, 1000, 500);
                }
            }
            break;
        }
    }

    private static void connectDevice(String address) {
        if (address.length() == 0) {
            ensureDiscoverable(30);
        	return;
        }

        mFound = true;

        // Get the BLuetoothDevice object
        BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(address);
        // Attempt to connect to the device
        mBluetoothService.connect(device);
    }

    /**
     * Start device discover with the BluetoothAdapter
     */
    private static void doDiscovery() {
        if (D) Log.d(TAG, "doDiscovery()");

        // If we're already discovering, stop it
        if (mBluetoothAdapter.isDiscovering()) {
            mBluetoothAdapter.cancelDiscovery();
        }

        // Request discover from BluetoothAdapter
        mBluetoothAdapter.startDiscovery();
    }

    // The BroadcastReceiver that listens for discovered devices and
    // changes the title when discovery is finished
    private static final BroadcastReceiver mReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();

            // When discovery finds a device
            if (BluetoothDevice.ACTION_FOUND.equals(action)) {
                // Get the BluetoothDevice object from the Intent
                BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                
                System.out.println("device: " + device.getName());
            	if (device.getName() != null 
            			&& device.getName().startsWith(BluetoothService.NAME_INSECURE) 
            			&&  device.getBondState() != BluetoothDevice.BOND_BONDED) {
                    String address = device.getAddress();
                    String myAddress = mBluetoothAdapter.getAddress();
                    
                    if (address.compareTo(myAddress) > 0) {
                    	return;
                    }
 
                    mBluetoothAdapter.cancelDiscovery();

                    connectDevice(device.getAddress());
            	}
            // When discovery is finished, change the Activity title
            } else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(action)) {
				BluetoothManager.nativeCalledFromBluetoothManager(mDelegate, RESULT_NOTFOUND_PEER, STATUS_ERROR, "ACTION_DISCOVERY_FINISHED", "", "");
            }
        }
    };
}
