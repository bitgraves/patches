(() => {
  const exposeToWindow = (obj) =>
      Object.entries(obj).forEach(([key, value]) => (window[key] = value));

  const sendToRepl = {
    testBitgraves: () => solid(0,0,1),

      initBitgraves: async () => {
          /* await loadScript('/extensions/hydra-arithmetics.js')
             await loadScript('/extensions/hydra-midi.js')
             await loadScript('/extensions/hydra-convolutions.js')
             await loadScript('/extensions/hydra-nonlinear-time.js')
             await midi.start({ input: '*', channel: '*' }) */

          const mpd218 = midi.input(0).channel(9);
          let _hit = 0; // set when pad touched in patch
          
          _aScale = 10;
          a.setBins(2);
          a.setScale(_aScale);

          s0.initImage("/assets/BITGRAVES_Final_2048_V02_04.jpg");
          pattern = () => src(s0).scale(0.5, 2, 2.6);

          let _offset = 0;
          let _offsetLerp = 0;
          
          update = () => {
              _offsetLerp += (_offset - _offsetLerp) * 0.1;
              _hit = _hit * 0.99;
          };
          tt = () => Math.max(0, time * (1.0 + _offsetLerp));
          ttl = (l = 60, lo = 0, hi = 1) => (lo + (hi - lo) * Math.min(1.0, (tt() / l)));
          ttls = (l = 60, lo = 0, hi = 1) => (lo + (hi - lo) * Math.min(1.0, (tt() / l) * (tt() / l)));

          wrapMainScene = (sceneFn) => {
              // choo.state.hydra.hydra.synth.time = 0; // reset time
              _offset = 0;
              _offsetLerp = 0;
              
              sceneFn()
                  .modulateScrollY(noise(200, 2), cc(15).range(0,0.9))
                  .mult(cc(14))
                  .out()
          };

          wake1 = () => {
              console.log(`wake1`);
              mpd218.onNote(51, () => { _hit = 1 });

              return src(s0)
                  .modulate(blur(s0).modulate(voronoi(),0.05),.02)
                  .add(solid(1,1,1).mult(cc(3).range(1,0)))
                  .mask(
                      shape(2,() => (.1 + _hit * 0.5)).repeatY(20).scrollY(0,.04)
                          .sub(noise(400).mult(.02))
                          .mask(shape(4,cc(3).range(.5,.9)))
                          .scrollY(() => _hit * 100)
                          .modulateScale(noise(.5,.1),cc(3).value((v) => v + _hit * 2.5))
                          .modulateScale(shape(4,0,.8).modulateScale(shape(32,0,.8)),20)
                  )
                  .scale(1,.6,1)
                  .modulate(sharpen(o0,.08).scale(1.1).scrollY(() => Math.cos(time/3),.1))
                  .modulate(noise(1,() => _hit * 0.25).mult(() => 0.75 * _hit));
          };
          wake2 = () => {
              console.log(`wake2`);
              return shape(2,.1).repeatY(50).scrollY(0,.04)
                  .sub(noise(400).mult(.02))
                  .modulateRotate(voronoi(12).mask(shape(16,0.5,1)),() => 3.14 * (1 + Math.sin(time / 15)))
                  .scrollX(0,.04)
                  .mask(shape(16,() => 1.25 + 0.75 * Math.cos(time / 14),.5))
                  .modulateScale(
                      noise(10,.15).pixelate(5,5)
                          .diff(noise(10,1).pixelate(4.9,4.9))
                          .thresh(.88),
                      cc(3).range(0.1,100)
                  )
                  .add(osc(4,5).color(1,0,0).mult(cc(9).range(0,0.85)))
                  .scale(1,.6,1)
                  .modulatePixelate(sharpen(o0,.08).scale(1.1).scrollX(() => Math.cos(time/3),.1),10,cc(3).range(100,3));
          };
          bigfish = () => {
              console.log('bigfish');
              return shape(32,.8)
                  .mask(
                      voronoi(() => 18 + Math.sin(time/18)*14,.2).diff(voronoi(() => (17.9 + Math.sin(time/18)*14) - a.fft[0] * .4,.2))
                          .modulateRotate(noise(10,.1),.05)
                          .add(.2).contrast(2).luma(.2)
                  )
                  .scale(1,.6,1)
                  .add(
                      src(o0).modulateScale(noise(200),.02).mult(cc(13).value((v) => (0.9 + v * 1.08) + a.fft[0] * .1))
                          .rotate(0.001)
                  )
                  .add(src(o0).mask(shape(2,.01).scrollY(0,-.05)).mult(.4))
                  .diff(src(o0));
          };
          sleep2 = () => {
              console.log(`sleep2`);
              return shape(4,.9).repeat(20,20).invert()
                  .modulatePixelate(noise().pixelate(),cc(12).value((v) => 1 + (a.fft[0] * v * 100))) // glitch
                  .modulateRotate(voronoi(10,1).pixelate(40,40).rotate(3.14 * 0.25),3.14*2)
                  .modulateScale(shape(() => a.fft[0] * 32,0,.9).modulateScale(shape(32,0,.9)),10)
                  .mask(shape(32,.66,cc(3).value((v) => .2 + a.fft[0] * v * 2)))
                  .mask(shape(32,.66).mult(cc(12).range(1,0)).invert())
                  .scale(1,.6,1)
                  .diff(src(o0).color(1.2,-0.7,1).mult(cc(12)))
                  .modulate(src(o0).scrollY(() => Math.cos(time/3)),.1);
          };

      mpd218.onNote('*', () => {});
      test = () => solid(1,0,0);

      gSceneIndex = 0;
      setlist = [wake1, wake2, bigfish, sleep2];

      nextScene = () => {
        if (gSceneIndex == setlist.length - 1) gSceneIndex = 0;
        else gSceneIndex++;
        console.log(`play scene: ${gSceneIndex}`);
        wrapMainScene(setlist[gSceneIndex]);
      };
      prevScene = () => {
        if (gSceneIndex == 0) gSceneIndex = setlist.length - 1;
        else gSceneIndex--;
        console.log(`play scene: ${gSceneIndex}`);
        wrapMainScene(setlist[gSceneIndex]);
      };

      mpd218.onNote(36, prevScene);
      mpd218.onNote(37, nextScene);
      mpd218.onNote(38, () => (_offset -= 0.05));
      mpd218.onNote(39, () => (_offset += 0.05));
      mpd218.onNote(40, () => { _aScale /= 0.75; _aScale = Math.min(40, _aScale); a.setScale(_aScale) }); // bigger scale, less sensitive mic
      mpd218.onNote(41, () => { _aScale *= 0.75; _aScale = Math.max(5.625, _aScale); a.setScale(_aScale) }); // smaller scale, more sensitive mic

      test().out();
    },
  };

  exposeToWindow(sendToRepl);
})();
