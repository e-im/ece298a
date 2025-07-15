mkdir ~/ttsetup/
python3 -m venv ~/ttsetup/venv
source ~/ttsetup/venv/bin/activate


pip install -r ./tt/requirements.txt

export PDK_ROOT=~/ttsetup/pdk
export PDK=sky130A
export OPENLANE2_TAG=2.2.9

pip install https://github.com/TinyTapeout/libparse-python/releases/download/0.3.1-dev1/libparse-0.3.1-cp313-cp313-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
pip install openlane==$OPENLANE2_TAG
./tt/tt_tool.py --create-user-config --openlane2
./tt/tt_tool.py --harden --openlane2
