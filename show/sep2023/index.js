(() => {
  const exposeToWindow = (obj) =>
      Object.entries(obj).forEach(([key, value]) => (window[key] = value));

  const sendToRepl = {
    testBitgraves: () => solid(0,0,1),

    initBitgraves: async () => {
      await loadScript('https://cdn.jsdelivr.net/npm/hydra-midi@latest/dist/index.js');
      await midi.start({ input: '*', channel: '*' });

      await loadScript('https://hydra-extensions.glitch.me/hydra-arithmetics.js');
      midi.hide();

      a.setBins(2);
      s0.initImage('https://storage.googleapis.com/reading-supply-assets/reading.supply.df18bd35-5186-43bb-9eef-176187e37deb.jpeg');
      pattern = () => src(s0).scale(0.5, 2, 2.6);

      _offset = 0;
      _offsetLerp = 0;
      update = () => {
        _offsetLerp += (_offset - _offsetLerp) * 0.1;
      };
      tt = () => Math.max(0, time * (1.0 + _offsetLerp));
      ttl = (l = 60, lo = 0, hi = 1) => (lo + (hi - lo) * Math.min(1.0, (tt() / l)));
      ttls = (l = 60, lo = 0, hi = 1) => (lo + (hi - lo) * Math.min(1.0, (tt() / l) * (tt() / l)));

      wrapMainScene = (sceneFn) => {
        choo.state.hydra.hydra.synth.time = 0; // reset time
        _offset = 0;
        _offsetLerp = 0;
        
        sceneFn()
          .mult(cc(14))
          .out()
      };

      baikal1 = () => {
        LEN = 150;
        return shape(2, () => 0.01 + a.fft[0] * 0.1)
          .modulate(noise(2, () => ttls(LEN,1,5)), () => ttl(LEN,0,0.3))
          .diff(
            shape(2, () => 0.01 + a.fft[0] * 0.1)
              .modulate(noise(2.5, () => ttls(LEN,1,5)), () => ttl(LEN,0,0.3))
          )
          .scrollX(0, () => ttls(LEN,0,4))
          .scale(1,0.6,1)
          .add(src(o0).mult(0.8).scale(1.01, 1, 1.1));
      };

      baikal2 = () => {
        LEN = 150; // TODO
        return pattern().scrollY(() => Math.sin(time * 0.1) * 0.75)
          .mult(pattern().scrollX(() => time / 20))
          .scale(2.8)
          .modulateRotate(noise(8), 0.1)
          .modulateScale(osc(100).mult(0.08).rotate(3.14/2))
          .modulateRepeatY(osc(10).mult(() => a.fft[1] * 0.1))
          .repeat(() => ttl(LEN,2,4), () => ttl(LEN,2,4))
          .modulateScale(osc().mult(() => a.fft[1] * 0.1))
          .mask(shape(64,0,2.5))
          .scale(1,0.6,1)
          .add(src(o0).color(0.6,0.85,1).scale(1.005).mult(() => 0.2 + a.fft[1] * 0.8))
      };

      bigfish = () => {
        LEN = 240;
        return pattern().repeat(2).modulateKaleid(osc(2).mult(() => ttl(LEN)), 2)
          .mult(pattern().repeat(4).scrollX(() => Math.sin(time * 0.1) * ttl(120,0.2,4)))
          .modulateScale(osc(20).pixelate(80, 80).mult(() => a.fft[1] * 0.1).mult(() => ttl(LEN))) // fft wobble
          .modulateScale(shape(3).scale(1.5, 1.5).modulateRotate(osc(5)), () => ttl(LEN))
          .mult(noise(40, 1).thresh(0.7).add(() => ttl(60)).add(() => a.fft[0] * 0.5).pixelate(100, 100))
          .scale(1,0.6,1)
          .luma(0.5)
          .add(src(o0).mult(() => a.fft[1] * 0.4));
      };

      pluck2 = () => {
        LEN = 180 // TODO
        return pattern().scrollX(0,() => ttl(LEN,0.03,2)).repeat(4,4)
          .diff(pattern().repeat(4,4).scale(1.02).scrollX(0, () => -0.04 - ttl(LEN,0,0.96)).scrollY(0,-0.1))
          .add(
            shape(3).scale(1,0.5,2).repeat(8,1)
              .modulateScale(noise(20, 1).mult(() => a.fft[0] * 0.02))
              .modulateScale(osc(2).mult(() => ttls(LEN)), 2, 0.1)
          )
          .mult(() => 0.8 + a.fft[0] * 0.3)
          .add(src(o0).mult(() => ttls(LEN)).color(1,0.75,0.2))
          .diff(src(o0).mult(() => ttl(LEN + 30)).scale(0.5))
          .scale(1,0.6,1)
          .luma(0.5);
      };

      baaka = () => {
        return pattern().scrollY(() => Math.sin(time * 0.1) * 0.75)
          .mask(shape(32, 0.8))
          .modulate(noise(50, () => a.fft[1] * 0.0001).pixelate(200,200), () => 0.02 + Math.cos(tt() / 40) * 0.2)
          .modulateScale(osc(3).mult(0.2))
        // .add(src(o0).color(0,0.5,0.5).mult(() => a.fft[1] * 0.7))
          .scale(1,0.6,1)
          .add(src(o0).mult(cc(9).range(0,0.96)))
          .luma(0.5);
      };

      murmur = () => {
        INTRO = 60;
        LEN = 150;
        return pattern().scrollX(0,0.03).repeat(4,4)
          .diff(pattern().repeat(4,4).scale(1.02).scrollX(0,0.04).scrollY(0,-0.1))
          .mult(() => Math.max(ttl(INTRO), Math.min(1, a.fft[0] * 0.5)))
          .mask(
            noise(() => 5 - 1.2 * a.fft[0], () => 0.25 + a.fft[0] * 0.002).sub(0.1).thresh(0.6)
              .scale(() => 0.9 + a.fft[1] * 0.05)
              .modulatePixelate(osc(10, () => a.fft[1]).add(() => 1 - ttl(INTRO)), 50)
          )
          .modulateScrollY(voronoi(() => 3 + Math.sin(time * 0.01), 0.1),() => 1 + Math.sin(time / 10) * 0.5)
          .diff(
            src(o0).repeatY(4).color(1.05,0.8,1.05)
              .mult(osc(20,0.2)).modulateScale(osc(16).rotate(3.14/2).mult(() => a.fft[0] * 0.05)).mult(() => ttls(LEN))
          )
          .luma(0.1)
          .scale(1,0.6,1)
          .add(src(o0).mult(() => ttl(LEN) * 0.6).scale(() => 1.0005 + ttl(LEN) * 0.005));
      };

      unicorn = () => {
        waveCos = () => 0.5 + (Math.cos(tt() / 20) * 0.5);
        waveSin = () => 0.5 + (Math.sin(tt() / 20) * 0.5);
        return pattern().scrollX(0,0.03).repeat(4,4)
          .mult(
            shape(2, 0.1).modulateRotate(osc(32), 1).modulateRotate(noise(() => 32 + a.fft[0] * 0.3), () => 2 + waveCos() * 14)
              .diff(shape(2, () => waveSin() * 0.1).modulateRotate(osc(16), 1).modulateRotate(noise(16), () => 1 + waveCos() * 7))
          )
          .modulateScale(voronoi(4),() => waveSin() * 0.6)
          .mult(() => 0.8 + a.fft[0] * 0.3)
          .color(() => 1.0 - ttls(240))
          .mask(shape(32, () => ttl(120, 0, 2), () => ttl(120, 0.2, 0.7)))
          .scale(1,0.6,1)
          .add(src(o0).scale(0.99).mult(() => 0.2 + a.fft[0] * 0.4));
      };



      const mpd218 = midi.input(0).channel(9);
      mpd218.onNote('*', () => {});
      test = () => solid(1,0,0);

      gSceneIndex = 0;
      setlist = [test, baikal1, baikal2, bigfish, pluck2, baaka, murmur, unicorn];
      setlistScaleBeforeAdd = [false, false, false, false, false, true, true, true];

      nextScene = () => {
        if (gSceneIndex == setlist.length - 1) gSceneIndex = 0;
        else gSceneIndex++;
        console.log(`play scene: ${gSceneIndex}`);
        wrapMainScene(setlist[gSceneIndex], setlistScaleBeforeAdd[gSceneIndex]);
      };
      prevScene = () => {
        if (gSceneIndex == 0) gSceneIndex = setlist.length - 1;
        else gSceneIndex--;
        console.log(`play scene: ${gSceneIndex}`);
        wrapMainScene(setlist[gSceneIndex], setlistScaleBeforeAdd[gSceneIndex]);
      };

      mpd218.onNote(36, prevScene);
      mpd218.onNote(37, nextScene);
      mpd218.onNote(38, () => (_offset -= 0.05));
      mpd218.onNote(39, () => (_offset += 0.05));

      test().out();
    },
  };

  exposeToWindow(sendToRepl);
})();
