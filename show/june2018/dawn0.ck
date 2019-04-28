// before show, this was "robot-dawn-newdrone.ck"

// TODO: finalize initial pad attack (currently 1 sec)
// TODO: allow rerecord drone?

1 => int midiDeviceIndex;
1 => int enableOsc;

3 => int SLIDER_SPEED_ID;
9 => int SLIDER_TWIN_LPF_ID;
12 => int SLIDER_TWIN_ATTACK_ID;
13 => int SLIDER_BEND_VEL;
14 => int SLIDER_MONITOR_ID;
15 => int SLIDER_WET_ID;

// unused now
16 => int SLIDER_SPREAD_ID;
18 => int SLIDER_TEX_ID;

0 => float gSpeedDecay;
118.0 => float texDurationMs;
1.0 => float texDivisor;
0 => float texAmount;
0 => float spreadFactor;
1000 => float gTwinAttack;
-0.001 => float gBendVel;

OscSend oscTransmitter;

Gain wetGain => Dyno gWetLimiter => dac;
Gain harmonicGain => LPF harmonicFilter => Gain gSeparator;
20000 => harmonicFilter.freq;
0.985 => harmonicFilter.Q;

0.85 => gWetLimiter.gain;
gWetLimiter.limit();

// stereo separator for harmonics
Pan2 separator => dac;
Delay gSeparatorDelay;
7::ms => gSeparatorDelay.delay;
gSeparator => separator.left;
gSeparator => gSeparatorDelay => separator.right;

Gain droneGain => blackhole;
adc.left => Gain filterGain;
0 => wetGain.gain;

adc.left => Gain dryGain => dac;
0 => dryGain.gain;

Event evtDroneCapture;

fun void listenForMidi() {
    MidiIn min;
    MidiMsg msg;
    if (!min.open(midiDeviceIndex)) me.exit();
    while (true) {
        min => now;
        while (min.recv(msg)) {
            if (msg.data1 == 153) { // note on
                msg.data2 - 36 => int padIndex;
                if (padIndex == 15) {
                    evtDroneCapture.broadcast();
                    logToOsc(1, 15, 1, "capture drone");
                } else if (padIndex == 14) {
                    spork ~ bumpSpeed();
                } else {
                    TwinFilter tf;
                    spork ~ tf.run(droneGain, harmonicGain, gBendVel, 1 + padIndex);
                }
            } else if (msg.data1 == 137) { // note off
                1.0 => texDivisor;
            } else if (msg.data1 == 176) { // knob twist
                " " => string description;
                if (msg.data2 == SLIDER_SPEED_ID) {
                    (msg.data3 $ float) / 127.0 => float amount;
                    amount => gSpeedDecay;
                    "Accent decay " + (amount * 100.0) + "%" => description;
                } else if (msg.data2 == SLIDER_TEX_ID) {
                    (msg.data3 $ float) / 127.0 => float amount;
                    amount * 0.95 => texAmount;
                    "Tex " + (texAmount * 100.0) + "%" => description;
                } else if (msg.data2 == SLIDER_SPREAD_ID) {
                    (msg.data3 $ float) / 127.0 => float amount;
                    amount * 0.5 => spreadFactor;
                    "Harmonic spread " + spreadFactor => description;
                } else if (msg.data2 == SLIDER_TWIN_LPF_ID) {
                    1.0 - (msg.data3 $ float / 127.0) => float val;
                    20.0 + Math.pow(2, val * 14.2876) => harmonicFilter.freq;
                    "LPF harmonic " + harmonicFilter.freq() => description;
                } else if (msg.data2 == SLIDER_TWIN_ATTACK_ID) {
                    (msg.data3 $ float) / 127.0 => float amount;
                    1000 + (amount * 1500) => gTwinAttack;
                    "Pad attack " + gTwinAttack => description;
                } else if (msg.data2 == SLIDER_BEND_VEL) {
                    (msg.data3 $ float) / 127.0 => float amount;
                    // old behavior: allow both upward and downward bends
                    // -0.004 + amount * 0.008 => gBendVel;
                    -0.001 + amount * 0.001 => gBendVel;
                    "Bend " + gBendVel => description;
                } else if (msg.data2 == SLIDER_MONITOR_ID) {
                    (msg.data3 $ float) / 127.0 => float amount;
                    amount => dryGain.gain;
                    "Monitor " + (amount * 100.0) + "%" => description;
                } else if (msg.data2 == SLIDER_WET_ID) {
                    (msg.data3 $ float) / 127.0 => float amount;
                    amount => wetGain.gain;
                    "Filter " + (amount * 100.0) + "%" => description;
                }
                logToOsc(0, msg.data2, msg.data3, description);
            }
        }
    }
}

class DroneHolder {
    fun void run(UGen in, UGen out) {
        in => LiSa buf => out;
        // 30.0 => f.index;
        2::second => dur bufDur;
        bufDur => buf.duration;
        evtDroneCapture => now;
        buf.recRamp(2::ms);
        buf.record(1);
        bufDur => now;
        buf.record(0);
        buf.play(1);
        while (bufDur => now);
    }
}

class TwinFilter {
    PitShift _shift;
    0 => float _bendVel;
    0 => float _bendAmount;
    0 => int _isStopped;
    
    fun void run(UGen in, UGen out, float bendVel, int harmonicIdx) {
        440.0 * Math.pow(2, -19.0 / 12.0) => float baseFilterFreq;
        baseFilterFreq * harmonicIdx => float filterFreq;
        ((1.0 / filterFreq) * 8.0)::second => dur bufDur;

        in => BiQuad b => ADSR env => _shift => Chorus m => FoldbackSaturator f => out;
        30.0 => f.index;
        1 => _shift.mix;
        1 => _shift.shift;
        bendVel => _bendVel;
        logToOsc(1, 1, 0, "ghost " + harmonicIdx);

        0.006 => b.gain;
        0.999 => b.prad;
        1 => b.eqzs;
        filterFreq => b.pfreq;
        env.set((gTwinAttack)::ms, 1::ms, 1, (7000 - gTwinAttack)::ms);

        1 => env.keyOn;
        env.attackTime() => now;
        env.attackTime() => now; // yes do this again
        spork ~ _bend();
        1 => env.keyOff;
        env.releaseTime() => now;

        env =< out;
        1 => _isStopped;
    }

    fun void _bend() {
        while (5::ms => now) {
            if (_isStopped) break;
            _bendVel +=> _bendAmount;
            Math.pow(2.0, _bendAmount / 12.0) => _shift.shift;
        }
    }
}

class DawnFilter {
    fun float getFilterFreq(float base, int index, float spread) {
        return base * Math.pow(2, index * spread);
    }
    
    fun float getFilterRad(int index, float spread) {
        return Math.min(0.93 + Math.randomf() * 0.01 * index, 0.98);
    }
    
    fun void run(UGen in, UGen out) {
        Delay delays[4];
        Envelope delayEnvs[4];
        Gain allDelays;
        for (0 => int ii; ii < delays.cap(); ii++) {
            (15 + Math.random2(0, 4) * (ii + 1))::ms => delays[ii].delay;
            0.6 => delays[ii].gain;
            2::ms => delayEnvs[ii].duration;
            in => delays[ii] => delayEnvs[ii] => allDelays;
        }

        BiQuad filters[9];
        Envelope filterEnvs[9];
        ADSR outEnv;
        outEnv.set(10::samp, 5::ms, 1.0 - texAmount, 1::ms);
        // [-31, -19, -12, 0] @=> int notes[];
        //             440.0 * Math.pow(2, notes[ii] / 12.0) => filters[ii].pfreq;
        220.0 * Math.pow(2, -31.0 / 12.0) => float baseFilterFreq;
        for (0 => int ii; ii < filters.cap(); ii++) {
            0.025 => filters[ii].gain;
            0.93 => filters[ii].prad;
            1 => filters[ii].eqzs;
            baseFilterFreq * Math.pow(2, ii) => filters[ii].pfreq;
            2::ms => filterEnvs[ii].duration;
            allDelays => filters[ii] => filterEnvs[ii] => outEnv;
        }
        outEnv => out;
        
        while ((texDurationMs / texDivisor)::ms => now) {
            outEnv.set(5::ms, 5::ms, 1.0 - texAmount, 1::ms); // TODO: param listener
            1 => outEnv.keyOff;
            outEnv.releaseTime() => now;
            1 => outEnv.keyOn;
            for (0 => int ii; ii < delays.cap(); ii++) {
                0.2 + Math.randomf() * 0.8 => delayEnvs[ii].target;
                (15 + Math.random2(0, 4) * (ii + 1))::ms => delays[ii].delay;
            }
            for (0 => int ii; ii < filters.cap(); ii++) {
                (1.0 - spreadFactor) * (Math.randomf() * spreadFactor * 2.0) => float spread;
                getFilterFreq(baseFilterFreq, ii, spread) => filters[ii].pfreq;
                getFilterRad(ii, spread) => filters[ii].prad;
                if (ii >= 6) {
                    // keep really high freqs in
                    0.8 + Math.randomf() * 0.2 => filterEnvs[ii].target;
                } else {
                    0.2 + Math.randomf() * 0.8 => filterEnvs[ii].target;
                }
            }
            /* for (0 => int ii; ii < filters.cap(); ii++) {
                if (ii < 6) {
                    filterEnvs[ii].target() / maxFilterTarget => filterEnvs[ii].target;
                }
            } */
        }
    }
}

fun void bumpSpeed() {
    // (msg.data3 $ float) / 127.0 => float amount;
    // 10 + 108 * (1.0 - amount) => texDurationMs;
    logToOsc(1, 0, 0, "Yo");
    10 => texDurationMs;
    280::ms => now;
    do {
        10.0 - (9.0 * gSpeedDecay) => float minAmount;
        minAmount * 2.0 => float maxAmount;
        texDurationMs + Math.random2f(minAmount, maxAmount) => texDurationMs;
        if (texDurationMs >= 100) break;
    } while ((10.0 + (20.0 * gSpeedDecay))::ms => now);
    118 => texDurationMs;
}

fun void logToOsc(int type, int param, int value, string description) {
    if (enableOsc) {
        oscTransmitter.startMsg("/param", "i i i s");
        type => oscTransmitter.addInt;
        param => oscTransmitter.addInt;
        value => oscTransmitter.addInt;
        description => oscTransmitter.addString;
    }
    <<< description >>>;
    return;
}

if (enableOsc) {
    oscTransmitter.setHost("localhost", 4242);
    logToOsc(1, 15, 0, "drone not captured");
}

DawnFilter df;
DroneHolder dh;

spork ~ df.run(filterGain, wetGain);
spork ~ dh.run(filterGain, droneGain);
spork ~ listenForMidi();
while (1::day => now);
