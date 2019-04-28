// before show, this was "ride-again.ck"

1 => int midiDeviceIndex;
1 => int enableOsc;

3 => int SLIDER_BASE_ID;
9 => int SLIDER_SPREAD_ID;
12 => int SLIDER_SAMPLE_SPEED_ID;
13 => int SLIDER_SAMPLE_RANDOM_ID;
14 => int SLIDER_MONITOR_ID;
15 => int SLIDER_ENV_SPEED_ID;

12 => int ALT_SLIDER_STUTTER_ID;
13 => int ALT_SLIDER_BC_DOWN_ID;

OscSend oscTransmitter;

adc.left => Gain monitorGain => dac;
0 => monitorGain.gain;

adc.left => ADSR globalEnv => Gain inputGain;
globalEnv.set(10::ms, 0::ms, 1, 25::ms);
1 => globalEnv.keyOn;

// inputGain -> N voices -> limiter -> dac.left
//                       -> crossGain -> crossShift -> more voices -> dac.left
Gain crossGain => Dyno gVoiceLimiter => dac;
5.0 => crossGain.gain;
gVoiceLimiter.limit();
0.4 => gVoiceLimiter.gain;

// stereo separator for higher voices
Gain gSeparator;
Pan2 separator => dac;
Delay gSeparatorDelay;
3::ms => gSeparatorDelay.delay;
gSeparator => separator.left;
gSeparator => gSeparatorDelay => separator.right;

0 => int gUseAltControlIds;

1 => float gStutter;

0 => float gPitchSpread;
1 => float gPitchBase;
0 => float gSampleSpeed;
0 => float gSampleRandom;
3 => int numVoices;

Bitcrusher gBitCrusher;
PitShift crossPitch;
3 => gBitCrusher.bits;
11 => gBitCrusher.downsampleFactor;

class VoiceEvent extends Event {
    int voiceIndex;
    int paramId;
    float value;
}
VoiceEvent event;
999 => int VOICE_INDEX_ALL;

0 => int PARAM_ENV_ID;
1 => int PARAM_BASE_ID;
2 => int PARAM_PITCH_ID;
3 => int PARAM_ENV_SPEED_ID;
4 => int PARAM_BASE_ALT_ID;
5 => int PARAM_PITCH_ALT_ID;

/**
 * sample config
 */
5 => int numBuffers;
2 => int poolSize;
[ "00.wav", "01.wav", "02.wav", "03.wav", "04.wav" ] @=> string bufSources[];

Sample samplePool[numBuffers][poolSize];
int samplePoolNextIndex[numBuffers];
loadSamplePool(numBuffers, poolSize, dac);

fun void listenForMidi() {
    MidiIn min;
    MidiMsg msg;
    if (!min.open(midiDeviceIndex)) me.exit();
    while (true) {
        min => now;
        while (min.recv(msg)) {
            if (msg.data1 == 153) { // note on
                msg.data2 - 36 => int noteIndex;
                if (noteIndex < numBuffers) {
                    nextSample(noteIndex) @=> Sample s;
                    spork ~ s.run(gSampleSpeed, gSampleRandom);
                    logToOsc(1, 0, 0, "vox" + noteIndex);
                    renderToOsc(0, 100, 85);
                } else if (noteIndex == 12) {
                    1 => globalEnv.keyOff;
                } else if (noteIndex == 13) {
                    PARAM_ENV_ID => event.paramId;
                    1 => event.value;
                    0 => int startIdx;
                    numVoices => int endIdx;
                    if (gUseAltControlIds) {
                        numVoices => startIdx;
                        numVoices + 2 => endIdx;
                    }
                    for (startIdx => int ii; ii < endIdx; ii++) {
                        ii => event.voiceIndex;
                        event.broadcast();
                        1::ms => now;
                    }
                } else if (noteIndex == 14) {
                    PARAM_ENV_ID => event.paramId;
                    0 => event.value;
                    0 => int startIdx;
                    numVoices => int endIdx;
                    if (gUseAltControlIds) {
                        numVoices => startIdx;
                        numVoices + 2 => endIdx;
                    }
                    for (startIdx => int ii; ii < endIdx; ii++) {
                        ii => event.voiceIndex;
                        event.broadcast();
                        1::ms => now;
                    }
                } else if (noteIndex == 15) {
                    logToOsc(1, 0, 0, "enable alt controls");
                    1 => gUseAltControlIds;
                } else if (noteIndex == 8) {
                    Math.pow(2.0, 43.0 / 12.0) => crossPitch.shift;
                    logToOsc(1, 0, 0, "octave on");
                }
            } else if (msg.data1 == 137) { // note off
                msg.data2 - 36 => int noteIndex;
                if (noteIndex == 12) {
                    1 => globalEnv.keyOn;
                } else if (noteIndex == 15) {
                    logToOsc(1, 0, 0, "disable alt controls");
                    0 => gUseAltControlIds;
                } else if (noteIndex == 8) {
                    Math.pow(2.0, 31.0 / 12.0) => crossPitch.shift;
                    logToOsc(1, 0, 0, "octave off");
                }
            } else if (msg.data1 == 176) { // knob twist
                (msg.data3 $ float) / 127.0 => float amount;
                " " => string description;
                if (msg.data2 == SLIDER_MONITOR_ID) {
                    amount => monitorGain.gain;
                    "Monitor " + amount => description;
                } else if (msg.data2 == SLIDER_BASE_ID) {
                    1.0 - amount => gPitchBase;
                    VOICE_INDEX_ALL => event.voiceIndex;
                    if (gUseAltControlIds) {
                        PARAM_BASE_ALT_ID => event.paramId;
                    } else {
                        PARAM_BASE_ID => event.paramId;
                    }
                    amount => event.value;
                    event.broadcast();
                    "Base " + gPitchBase => description;
                } else if (msg.data2 == SLIDER_SPREAD_ID) {
                    amount => gPitchSpread;
                    VOICE_INDEX_ALL => event.voiceIndex;
                    if (gUseAltControlIds) {
                        PARAM_PITCH_ALT_ID => event.paramId;
                    } else {
                        PARAM_PITCH_ID => event.paramId;
                    }
                    amount => event.value;
                    event.broadcast();
                    "Spread " + gPitchSpread => description;
                } else if (msg.data2 == SLIDER_ENV_SPEED_ID) {
                    VOICE_INDEX_ALL => event.voiceIndex;
                    PARAM_ENV_SPEED_ID => event.paramId;
                    amount => event.value;
                    event.broadcast();
                    "EnvSpeed " + amount => description;
                } else {
                    if (gUseAltControlIds) {
                        if (msg.data2 == ALT_SLIDER_STUTTER_ID) {
                            1.0 - amount => gStutter;
                            "stutter speed " + amount => description;
                        } else if (msg.data2 == ALT_SLIDER_BC_DOWN_ID) {
                            (11.0 + amount * 5.0) $ int => gBitCrusher.downsampleFactor;
                            ((3.0 + amount * 5.0) $ int)::ms => gSeparatorDelay.delay;
                            "downsample " + gBitCrusher.downsampleFactor() => description;
                        }
                    } else {
                        if (msg.data2 == SLIDER_SAMPLE_SPEED_ID) {
                            amount => gSampleSpeed;
                            "sample speed " + gSampleSpeed => description;
                        } else if (msg.data2 == SLIDER_SAMPLE_RANDOM_ID) {
                            amount => gSampleRandom;
                            "sample random " + gSampleRandom => description;
                        }
                    }
                }
                logToOsc(0, msg.data2, msg.data3, description);
            }
        }
    }
}


class Voice {
    Delay _d;
    PitShift _p;
    ADSR _env;
    int _index;
    int _paramBaseId;
    int _paramPitchId;

    fun void run(UGen in, UGen out, int index, int useAltControls) {
        if (useAltControls) {
            PARAM_BASE_ALT_ID => _paramBaseId;
            PARAM_PITCH_ALT_ID => _paramPitchId;
        } else {
            PARAM_BASE_ID => _paramBaseId;
            PARAM_PITCH_ID => _paramPitchId;
        }
        index => _index;
        in => _d => _p => _env => out;
        0.75 => _env.gain;
        1 => _p.mix;
        (index * 10)::ms => _d.delay;
        _updateEnvSpeed(0);
        _updatePitch();
        _listenForEvent();
    }

    fun void _updateEnvSpeed(float amount) {
        (1.0 + (amount * 3000))::ms => dur speed;
        _env.set(speed, 0::ms, 1, speed);
    }

    fun void _updatePitch() {
        gPitchBase + (0.1 * gPitchSpread * _index) => _p.shift;
    }
    
    fun void _listenForEvent() {
        while (event => now) {
            if (event.voiceIndex == _index || event.voiceIndex == VOICE_INDEX_ALL) {
                if (event.paramId == PARAM_ENV_ID) {
                    if (event.value > 0) {
                        1 => _env.keyOn;
                    } else {
                        1 => _env.keyOff;
                    }
                } else if (event.paramId == _paramPitchId || event.paramId == _paramBaseId) {
                    _updatePitch();
                } else if (event.paramId == PARAM_ENV_SPEED_ID) {
                    _updateEnvSpeed(event.value);
                }
            }
        }
    }
}

fun void loadSamplePool(int numSources, int poolSize, UGen out) {
    for (0 => int sourceIdx; sourceIdx < numSources; sourceIdx++) {
        for (0 => int poolIdx; poolIdx < poolSize; poolIdx++) {
            samplePool[sourceIdx][poolIdx].load(sourceIdx, out);
        }
    }
}

fun Sample nextSample(int sourceIndex) {
    samplePoolNextIndex[sourceIndex] => int nextPoolIndex;
    samplePool[sourceIndex][nextPoolIndex] @=> Sample result;
    nextPoolIndex++;
    poolSize %=> nextPoolIndex;
    nextPoolIndex => samplePoolNextIndex[sourceIndex];
    return result;
}

class Sample {
    SndBuf _buf;
    ADSR _env;
    PitShift _shift;
    int _index;
    Pan2 _pan;

    fun void load(int index, UGen out) {
        index => _index;
        "../../ghost-benvox/raw-" + bufSources[index] => _buf.read;
        _env.set(1::ms, 1::ms, 1, 1::ms);
        1 => _shift.mix;
        1 => _buf.phase;
        _buf => _shift => _env => _pan => out;
        1.4 => _buf.gain;
        <<< "load", index >>>;
    }
    
    fun void run(float speed, float random) {
        <<< "run", _index >>>;
        1 => _buf.phase;

        // if speed is 0, grainLength == buf.length and maxNumGrains is 1.
        // if speed is 1, grainLength == buf.length / 100 and maxNumGrains is 100.
        0 => int grainIndex;
        1.0 + (speed * 99.0) => float numGrains;
        _buf.length() / numGrains => dur grainLength;
        1 => _env.keyOn;
        Math.random2f(-1.0, 1.0) => _pan.pan;
        do {
            1 => _env.keyOff;
            _env.releaseTime() => now;
            if (grainIndex >= numGrains $ int) {
                break;
            }

            grainIndex => int phaseIndex;
            if (random > 0) {
                Math.random2(0, Math.ceil((numGrains $ float) * random) $ int) +=> phaseIndex;
                numGrains $ int %=> phaseIndex;
                Math.random2f(-1.0, 1.0) => _pan.pan;
            }
            (phaseIndex $ float) / numGrains => float phase;
            phase => _buf.phase;
            if (Math.randomf() < 0.8) {
                Math.pow(2.0, -1.0 / 12.0) => _shift.shift;
            } else {
                Math.pow(2.0, 4.0 / 12.0) => _shift.shift;
            }
            grainIndex++;
            1 => _env.keyOn;
            _env.attackTime() => now;
        } while (grainLength - _env.attackTime() - _env.releaseTime() => now);
        1 => _buf.phase;
    }
}

for (0 => int ii; ii < numVoices; ii++) {
    Voice v;
    spork ~ v.run(inputGain, crossGain, ii, 0);
}

// 3 voices output -> dac and also new pitshift -> spawn 3 more vox -> dac
gVoiceLimiter => crossPitch => ADSR thing => gBitCrusher;

thing.set(2::ms, 0::ms, 1, 2::ms);
fun void hackyThing() {
    while (true) {
        1 => thing.keyOn;
        (10 + (30 * gStutter))::ms => now;
        1 => thing.keyOff;
        (5 + (65 * gStutter))::ms => now;
    }
}
spork ~ hackyThing();

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

fun void renderToOsc(int type, int val1, int val2) {
    if (enableOsc) {
        oscTransmitter.startMsg("/render", "i i i");
        type => oscTransmitter.addInt;
        val1 => oscTransmitter.addInt;
        val2 => oscTransmitter.addInt;
    }
}

if (enableOsc) {
    oscTransmitter.setHost("localhost", 4242);
}

1 => crossPitch.mix;
0.4 => gBitCrusher.gain;
Math.pow(2.0, 31.0 / 12.0) => crossPitch.shift;
for (0 => int ii; ii < 2; ii++) {
    Voice v;
    spork ~ v.run(gBitCrusher, gSeparator, ii + numVoices, 1);
}

spork ~ listenForMidi();
while (1::day => now);
