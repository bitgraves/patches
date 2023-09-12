(() => {
  const exposeToWindow = (obj) =>
      Object.entries(obj).forEach(([key, value]) => (window[key] = value));

  const sendToRepl = {
    testBitgraves: () => solid(0,0,1),

    initBitgraves: async () => {
      await loadScript('https://cdn.jsdelivr.net/npm/hydra-midi@latest/dist/index.js');
      await midi.start({ input: '*', channel: '*' });
      await loadScript('https://hydra-extensions.glitch.me/hydra-arithmetics.js');

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
