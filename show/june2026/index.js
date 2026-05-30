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

      _aScale = 10;
      a.setBins(2);
      a.setScale(_aScale);

      s0.initImage("/assets/BITGRAVES_Final_2048_V02_04.jpg");
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
          .modulateScrollY(noise(200, 2), cc(15).range(0,0.9))
          .mult(cc(14))
          .out()
      };

      wake1 = () => {
          return shape(2);
      };
      wake2 = () => {
          return shape(4);
      };

      const mpd218 = midi.input(0).channel(9);
      mpd218.onNote('*', () => {});
      test = () => solid(1,0,0);

      gSceneIndex = 0;
      setlist = [wake1, wake2];

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
