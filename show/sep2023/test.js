const exposeToWindow = (obj) =>
      Object.entries(obj).forEach(([key, value]) => (window[key] = value));

test = {
  testScene: () => solid(0,0,1),
};

exposeToWindow(test);
