(() => {
  const exposeToWindow = (obj) =>
      Object.entries(obj).forEach(([key, value]) => (window[key] = value));

  const sendToRepl = {
    testBitgraves: () => solid(0,0,1),

    initBitgraves: async () => {
      await loadScript('https://cdn.jsdelivr.net/npm/hydra-midi@latest/dist/index.js');
      await midi.start({ input: '*', channel: '*' });
      await loadScript('https://hydra-extensions.glitch.me/hydra-arithmetics.js');

      s0.initImage('https://storage.googleapis.com/reading-supply-assets/reading.supply.df18bd35-5186-43bb-9eef-176187e37deb.jpeg');
      pattern = () => src(s0).scale(0.5, 2, 2.6);

      wrapMainScene = (sceneFn, scaleBeforeAdd = false) => {
        choo.state.hydra.hydra.synth.time = 0; // reset time
        if (scaleBeforeAdd) {
          sceneFn()
            .scale(1,0.6,1)
            .add(src(o0).mult(cc(9).range(0,0.96)))
            .mult(cc(14))
            .luma(0.5)
            .out()
        } else {
          sceneFn()
            .add(src(o0).mult(cc(9).range(0,0.96)))
            .scale(1,0.6,1)
            .mult(cc(14))
            .luma(0.5)
            .out()
        }
      };

      baikal1 = () => {
        scaleBigNoise = () => cc(3).range(0,1).value((v) => (v > 0.4) ? ((v - 0.4) / 0.6) : 0);
        return shape(2, () => 0.005 + a.fft[0] * 0.07)
          .repeat(1, cc(3).range(1,3))
          .modulateRotate(noise(cc(3).range(0.1,4), 0.2).mult(cc(3).range(0,0.75)))
          .scrollY(0, cc(3).range(0,3))
          .modulateRotate(noise(30, scaleBigNoise()).mult(scaleBigNoise()))
          .rotate(scaleBigNoise())
          .repeat(2,2)
          .mult(() => 0.8 + a.fft[0] * 0.3);
      };

      baikal2 = () => {
        return pattern().scrollY(() => Math.sin(time * 0.1) * 0.75)
          .mult(pattern().scrollX(() => time / 20))
          .scale(2.8)
          .modulateRotate(noise(8), 0.1)
          .modulateScale(osc(100).mult(0.08).rotate(3.14/2))
          .modulateRepeatY(osc(10).mult(() => a.fft[1] * 0.1))
          .repeat(4,4)
          .modulateScale(osc().mult(() => a.fft[1] * 0.1))
          .add(src(o0).color(0,0.5,0.5).mult(() => a.fft[1] * 0.7));
      };

      bigfish = () => {
        return pattern().repeat(2).modulateKaleid(osc(2).mult(cc(3)), 2)
          .mult(pattern().repeat(4).scrollX(() => Math.sin(time * 0.1) * 4))
          .modulateScale(osc(20).pixelate(80, 80).mult(() => a.fft[1] * 0.1).mult(cc(3))) // fft wobble
          .modulateScale(shape(3).scale(1.5, 1.5).modulateRotate(osc(5)), cc(3))
          .mult(noise(40, 1).thresh(0.7).add(cc(14)).add(() => a.fft[0] * 0.5).pixelate(100, 100));
      };

      pluck2 = () => {
        return pattern().scrollX(0,cc(9).range(0.03,2)).repeat(4,4)
          .diff(pattern().repeat(4,4).scale(1.02).scrollX(0,cc(3).range(-0.04,-0.1)).scrollY(0,-0.1))
          .add(
            shape(3).scale(1,0.5,2).repeat(8,1)
              .modulateScale(noise(20).mult(() => a.fft[1] * 0.01))
              .modulateScale(osc(2).mult(cc(3)), 2, 0.1)
          )
          .mult(() => 0.8 + a.fft[0] * 0.3)
        // .add(src(o0).mult(cc(9)))
          .diff(src(o0).mult(cc(3).range(0,1)).scale(0.5));
      };

      baaka = () => {
        return pattern().scrollY(() => Math.sin(time * 0.1) * 0.75)
          .mask(shape(32, 0.8))
          .modulate(noise(50, () => a.fft[1] * 0.0001).pixelate(200,200), cc(3).range(0.01,0.2))
          .modulateScale(osc(3).mult(0.2))
        // .add(src(o0).color(0,0.5,0.5).mult(() => a.fft[1] * 0.7))
      };

      murmur = () => {
        return pattern().scrollX(0,0.03).repeat(4,4)
          .diff(pattern().repeat(4,4).scale(1.02).scrollX(0,0.04).scrollY(0,-0.1))
          .mask(
            noise(() => 5 - 1.2 * a.fft[0], () => 0.25 + a.fft[0] * 0.002).sub(0.1).thresh(0.6)
              .scale(() => 0.9 + a.fft[1] * 0.05)
              .modulatePixelate(osc(10, () => a.fft[1]).add(cc(3).range(1,0)), 50)
          )
          .modulateScrollY(voronoi(() => 3 + Math.sin(time * 0.01), 0.1),() => 1 + Math.sin(time / 10) * 0.5)
          .mult(() => 0.5 + a.fft[0] * 0.6)
      };

      unicorn = () => {
        return pattern().scrollX(0,0.03).repeat(4,4)
          .mult(
            shape(2, 0.1).modulateRotate(osc(32), 1).modulateRotate(noise(32), cc(3).range(16,2))
              .diff(shape(2, cc(3).range(0,0.1)).modulateRotate(osc(16), 1).modulateRotate(noise(16), cc(3).range(8,1)))
          )
          .modulateScale(voronoi(4),cc(3).range(0,0.6))
          .mult(() => 0.8 + a.fft[0] * 0.3)
          .color(cc(3).range(1,0.1));
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
      /* mpd218.onNote(40, () => wrapMainScene(baikal1));
         mpd218.onNote(41, () => wrapMainScene(baikal2));
         mpd218.onNote(42, () => wrapMainScene(bigfish));
         mpd218.onNote(43, () => wrapMainScene(pluck2));
         mpd218.onNote(44, () => wrapMainScene(murmur, true));
         mpd218.onNote(45, () => wrapMainScene(unicorn, true)); */

      test().out();
    },
  };

  exposeToWindow(sendToRepl);
})();
