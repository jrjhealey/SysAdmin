#!/bin/bash

# Mount the university's Petabyte server as a samba/CIFS disk under /petabyte/
# Requires that a credentials file exist that contains university login details
# of the form:
# username=<username>
# password=<password>
# domain=ADS (for example)

sudo mount -t cifs "//llama.ads.warwick.ac.uk/HCSS1/Shared291/" /petabyte/ -o credentials=/home/wms_joe/.petabyte_credentials,vers=3\.0






