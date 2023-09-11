(() => {
  const exposeToWindow = (obj) =>
      Object.entries(obj).forEach(([key, value]) => (window[key] = value));

  const sendToRepl = {
    testBitgraves: () => solid(0,0,1),

    initBitgraves: () => {
      s0.initImage('https://storage.googleapis.com/reading-supply-assets/reading.supply.df18bd35-5186-43bb-9eef-176187e37deb.jpeg');
      pattern = () => src(s0).scale(0.5, 2, 2.6);

      scene1 = () => solid(1,0,0).out();
      scene2 = () => solid(0,1,0).out();

      const mpd218 = midi.input(0).channel(9);
      mpd218.onNote('*', () => {});
      mpd218.onNote(36, scene1);
      mpd218.onNote(37, scene2);
    },
  };

  exposeToWindow(sendToRepl);
})();
