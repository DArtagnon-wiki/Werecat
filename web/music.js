// Werecat web music: both loops decoded once by the browser and played by
// Web Audio on its own thread, so slow game frames never make them stutter.
// The game drives it through window.WCMusic (see scripts/audio.gd).
(function () {
  if (window.WCMusic) return;
  const M = {
    ctx: null, master: null, gains: [], srcs: [], bufs: {}, vol: [1, 0], level: 1,
    variant: "full", running: true, wanted: false, loading: null, startedVariant: null,
    ext: null,
    pickExt() {
      if (this.ext) return this.ext;
      const a = document.createElement("audio");
      this.ext = a.canPlayType('audio/ogg; codecs="vorbis"') ? "ogg" : "m4a";
      return this.ext;
    },
    ensureCtx() {
      if (this.ctx) return;
      const C = window.AudioContext || window.webkitAudioContext;
      if (!C) return;
      this.ctx = new C();
      this.master = this.ctx.createGain();
      this.master.connect(this.ctx.destination);
      for (let i = 0; i < 2; i++) {
        const g = this.ctx.createGain();
        g.gain.value = this.vol[i];
        g.connect(this.master);
        this.gains.push(g);
      }
      this.applyMaster();
    },
    async load(variant) {
      const key = variant;
      if (this.bufs[key]) return this.bufs[key];
      const sfx = variant === "lite" ? "_lite" : "";
      const get = async (name, ext) => {
        const r = await fetch(`music/${name}${sfx}.${ext}`);
        const ab = await r.arrayBuffer();
        return await new Promise((ok, fail) => this.ctx.decodeAudioData(ab, ok, fail));
      };
      const both = async (ext) => Promise.all([get("cute", ext), get("scary", ext)]);
      let b;
      try { b = await both(this.pickExt()); }
      catch (e) { this.ext = "m4a"; b = await both("m4a"); }
      this.bufs = {};          // keep only the variant in use (memory)
      this.bufs[key] = b;
      return b;
    },
    async start() {
      this.wanted = true;
      this.ensureCtx();
      if (!this.ctx) return;
      if (this.ctx.state === "suspended" && this.running) { try { await this.ctx.resume(); } catch (e) {} }
      if (this.startedVariant === this.variant || this.loading) return;
      const v = this.variant;
      this.loading = this.load(v);
      let bufs;
      try { bufs = await this.loading; } finally { this.loading = null; }
      if (v !== this.variant) { return this.start(); }
      this.stopSources();
      const t = this.ctx.currentTime + 0.05;
      for (let i = 0; i < 2; i++) {
        const s = this.ctx.createBufferSource();
        s.buffer = bufs[i];
        s.loop = true;
        s.connect(this.gains[i]);
        s.start(t);
        this.srcs.push(s);
      }
      this.startedVariant = v;
      if (!this.running) this.ctx.suspend();
    },
    stopSources() {
      for (const s of this.srcs) { try { s.stop(); } catch (e) {} s.disconnect(); }
      this.srcs = [];
      this.startedVariant = null;
    },
    setVariant(v) {
      if (v === this.variant) return;
      this.variant = v;
      if (this.wanted && this.ctx) this.start();
    },
    setVol(a, b) {
      this.vol = [a, b];
      if (!this.ctx) return;
      const t = this.ctx.currentTime;
      for (let i = 0; i < 2; i++) this.gains[i].gain.setTargetAtTime(this.vol[i], t, 0.08);
    },
    setLevel(l) { this.level = l; this.applyMaster(); },
    applyMaster() {
      if (!this.master) return;
      this.master.gain.setTargetAtTime(this.level * 0.7, this.ctx.currentTime, 0.05);
    },
    setRunning(on) {
      this.running = on;
      if (!this.ctx) return;
      if (on) { if (this.wanted) this.ctx.resume(); } else { this.ctx.suspend(); }
    },
    // for tests
    state() { return { ctx: this.ctx ? this.ctx.state : "none", playing: this.srcs.length, variant: this.startedVariant, vol: this.vol, ext: this.ext }; },
  };
  window.WCMusic = M;
  // Audio may only start from a user gesture: start (or resume) on any tap.
  const kick = () => { if (M.running) M.start(); };
  for (const ev of ["pointerdown", "touchend", "keydown", "mousedown"]) document.addEventListener(ev, kick, { passive: true });
})();
