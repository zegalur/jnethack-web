cd jnethack-release

# explicitly set 32bit compiler
export CC="clang -m32"
export CXX="clang++ -m32"

./configure --host=i686-linux-gnu
make
make install
