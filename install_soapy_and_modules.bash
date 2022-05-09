#! /bin/bash

set -e

SCRIPT_PATH=`realpath "$0"`
SCRIPT_DIR=`dirname "$SCRIPT_PATH"`
BUILD_DIR="$SCRIPT_DIR/build"


function install_prerequisites() 
{
	echo "Install prerequisites"

	sudo apt-get install git build-essential automake cmake g++ swig
	sudo apt-get install libgtk2.0-dev libpulse-dev python-numpy
	sudo apt-get install mesa-utils 
	sudo apt-get install freeglut3-dev freeglut3 gtk+-3.0
}

function install_hackrf_prerequisites() 
{
	if [[ ! -f /etc/apt/sources.list.d/myriadrf-ubuntu-drivers-focal.list ]]; then
		sudo add-apt-repository -y ppa:myriadrf/drivers
		sudo apt-get update
	fi
	sudo apt-get install hackrf libhackrf-dev
}

function build_liqued_dsp() 
{
	echo "Build liquid-dsp"
	
	cd "$BUILD_DIR"
	if [ ! -d "$BUILD_DIR/liquid-dsp" ]; then
		git clone https://github.com/jgaeddert/liquid-dsp --depth=1
	fi

	cd liquid-dsp
	if [ ! -f "/usr/local/lib/libliquid.so" ]; then
		./bootstrap.sh
		./configure --enable-fftoverride 
		make
		sudo make install
		sudo ldconfig
	fi
	cd ..
}

function build_wxwidgets() {
	echo "Build wxwidgets"

	cd "$BUILD_DIR"
	if [ ! -f "$BUILD_DIR/wxWidgets-3.1.1.tar.bz2" ]; then
		wget -c https://github.com/wxWidgets/wxWidgets/releases/download/v3.1.1/wxWidgets-3.1.1.tar.bz2
	fi

	if [ ! -d "$BUILD_DIR/wxWidgets-3.1.1" ]; then
		tar -xvjf wxWidgets-3.1.1.tar.bz2  
	fi

	cd wxWidgets-3.1.1
	if [ -f $BUILD_DIR/wxWidgets-staticlib/bin/wx-config ]; then
		return 0
	fi

	mkdir -p "$BUILD_DIR/wxWidgets-staticlib"
	./autogen.sh 
	./configure --with-opengl --disable-shared --enable-monolithic --with-libjpeg --with-libtiff --with-libpng --with-zlib --disable-sdltest --enable-unicode --enable-display --enable-propgrid --disable-webkit --disable-webview --disable-webviewwebkit --with-gtk=3 --prefix="$BUILD_DIR/wxWidgets-staticlib" CXXFLAGS="-std=c++0x" --with-libiconv=/usr
	make
	sudo make install
	cd ..
}

function soap_sdr_play_service() 
{
	echo "[Unit]
Description=SDRplay API Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=on-failure
RestartSec=1
User=root
ExecStart=/usr/local/bin/sdrplay_apiService

[Install]
WantedBy=multi-user.target
" > /tmp/sdrplay.service 
	sudo mv /tmp/sdrplay.service /etc/systemd/system/sdrplay.service
	sudo chown root:root /etc/systemd/system/sdrplay.service
	sudo chmod ug+x /etc/systemd/system/sdrplay.service
}

function build_soapy_sdr() 
{
	echo "Build SoapySDR"

	cd "$BUILD_DIR"

	if [ ! -d "$BUILD_DIR/SoapySDR" ]; then
		git clone https://github.com/pothosware/SoapySDR.git --depth=1
	fi

	cd SoapySDR
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make
	sudo make install
	sudo ldconfig
	cd ..
	cd ..
}

# Now we build the SDRPlay module for Soapy
function build_soapy_sdr_play() {
	echo "Build SoapySDRPlay3"

	cd "$BUILD_DIR"
	if [ ! -d "$BUILD_DIR/SoapySDRPlay3" ]; then
		git clone https://github.com/pothosware/SoapySDRPlay3.git --depth=1
	fi

	cd SoapySDRPlay3
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make
	sudo make install
	cd ..
	cd ..
}

# Now we build the SDRPlay module for Soapy
function build_soapy_hackrf() {
	echo "Build HackRF"

	cd "$BUILD_DIR"
	if [ ! -d "$BUILD_DIR/SoapyHackRF" ]; then
		git clone https://github.com/pothosware/SoapyHackRF.git --depth=1
	fi

	cd SoapyHackRF
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make
	sudo make install
	cd ..
	cd ..
}

# And we build SoapyRemote

function build_soapy_remote() {
	echo "Build SoapyRemote"

	cd "$BUILD_DIR"
	if [ ! -d "$BUILD_DIR/SoapyRemote" ]; then
		git clone https://github.com/pothosware/SoapyRemote.git --depth=1
	fi

	cd SoapyRemote
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make
	sudo make install
	cd ..
	cd ..
}

# And finally,  we build Cubic.  This takes awhile!
function build_cubic_sdr() {
	echo "Build CubicSDR"

	cd "$BUILD_DIR"
	if [ ! -d "$BUILD_DIR/CubicSDR" ]; then
		git clone https://github.com/cjcliffe/CubicSDR.git --depth=1
	fi
	cd CubicSDR
	mkdir -p build
	cd build
	cmake ../ -DCMAKE_BUILD_TYPE=Release -DwxWidgets_CONFIG_EXECUTABLE="$BUILD_DIR/wxWidgets-staticlib/bin/wx-config" -DOpenGL_GL_PREFERENCE="LEGACY"
	make
	sudo make install
	sudo ldconfig
	cd ..
	cd ..
}

function blacklist_modules() 
{
	echo "Blacklist sdr unsupported kernel modules"
	grep 'msi001' /etc/modprobe.d/blacklist.conf || sudo bash -c "echo 'blacklist sdr_msi3101
blacklist msi001
blacklist msi2500' >> /etc/modprobe.d/blacklist.conf"

}

# now we change permissions on these root-owned folders so the user can 
# delete them at their leisure.

mkdir -p "$BUILD_DIR"

echo

install_prerequisites
install_hackrf_prerequisites
build_liqued_dsp
build_wxwidgets
build_soapy_sdr
build_soapy_sdr_play
build_soapy_hackrf
soap_sdr_play_service
blacklist_modules
build_soapy_remote
build_cubic_sdr

echo 'SoapySDRUtil --probe="driver=sdrplay"'
echo 'SoapySDRUtil --probe="driver=hackrf"'
