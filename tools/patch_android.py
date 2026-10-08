import pathlib

PERMS = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="false"/>
"""

p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text()
if "BLUETOOTH_SCAN" not in s:
    s = s.replace("<application", PERMS + "    <application", 1)
s = s.replace('android:label="signal_radar"', 'android:label="Signal Radar"')
p.write_text(s)
print("Manifest patched")
