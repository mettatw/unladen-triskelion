FROM ninja_builder:1.8.2

# --no-pie is because newer gccs tend to by default enable pie
RUN wget --no-check-certificate https://github.com/ninja-build/ninja/archive/v1.8.2.tar.gz \
  && tar xf v1.8.2.tar.gz \
  && cd ninja-1.8.2 \
  && CXXFLAGS="-g0 -O3" LDFLAGS="-static -Wl,-O3 -no-pie" ./configure.py --bootstrap \
  && strip --strip-all ninja \
  && upx --best ninja
