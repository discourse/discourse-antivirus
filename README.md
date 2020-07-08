# discourse-antivirus

Scan your Discourse uploads using ClamAV.

## Using the plugin in production

To use this plugin in production, you must provide an SRV record that resolves to the hostnames/ports where ClamAV is running. See the `antivirus_srv_record` site setting.

## Using the plugin locally

To communicate with your local ClamAV server, add the `clamav_hostname` and `clamav_port` variables to your `discourse.conf` file.

## Background scans

The plugin will perform background scans regularly. We use the following cadence to scan files: 

- Scan an upload if we never scanned it before.
- Scan on every ClamAV database update until the upload is one week old.
- Re-scan occasionally but at ever-increasing intervals independently of definition updates

## Real-time Scanning

We scan uploads before they get uploaded to the store by listening to the `:before_upload_creation` event, and sending the file to the antivirus. 

We skip images by default, enable the `antivirus_live_scan_images` site setting if you want to real-time scan them.

## Testing the plugin

If you're looking for a file to upload and test the plugin yourself, take a look at the [EICAR test file](https://en.wikipedia.org/wiki/EICAR_test_file)