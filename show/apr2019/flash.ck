
1 => int midiDeviceIndex;
1 => int enableOsc;

3 => int SLIDER_BEND_LO_ID;
0 => float gBendLo;
9 => int SLIDER_BEND_TOP_ID;
0 => float gBendTop;
12 => int SLIDER_SHIFT_SAMPLER_ID;
14 => int SLIDER_MONITOR_ID;
15 => int SLIDER_SHIFT_GAIN_ID;
1 => float gShiftSampler;

12 => int PAD_SPAWN_SAMPLER_ID;
13 => int PAD_STOP_SAMPLERS_ID;
15 => int PAD_ENABLE_SAMPLER_ID;

Event evtParam;

class EnvelopeEvent extends Event {
    int index;
    int on;
}
EnvelopeEvent evtEnvelope;

Event evtStopSamplers;

Gain wetGain;
Gain samplerGain;// => wetGain;
Gain shiftGain;
ADSR sacrificeEnv => dac;
sacrificeEnv.set(2::ms, 1::ms, 1.0, 2::ms);
0.5 => shiftGain.gain;
0 => sacrificeEnv.gain;
// 0 => samplerGain.gain;
adc.left => Gain inputGain;

adc.left => Gain monitorGain;
0 => monitorGain.gain;

OscSend oscTransmitter;

fun void listenForMidi() {
    MidiIn min;
    MidiMsg msg;
    if (!min.open(midiDeviceIndex)) me.exit();
    while (true) {
        min => now;
        while (min.recv(msg)) {
            " " => string description;
            if (msg.data1 == 153) { // note on
                msg.data2 - 36 => int noteIndex;
                if (noteIndex < 4) {
                    noteIndex => evtEnvelope.index;
                    1 => evtEnvelope.on;
                    evtEnvelope.broadcast();
                    "on " + evtEnvelope.index => description;
                    logToOsc(1, noteIndex, 1, description);
                } else if (noteIndex < 8) {
                    noteIndex - 4 => evtEnvelope.index;
                    0 => evtEnvelope.on;
                    evtEnvelope.broadcast();
                    "off " + evtEnvelope.index => description;
                    logToOsc(1, noteIndex - 4, 0, description);
                } else if (noteIndex == PAD_SPAWN_SAMPLER_ID) {
                    Sampler s;
                    spork ~ s.loop(adc.left, samplerGain);
                    "Spawn loop" => description;
                    logToOsc(1, noteIndex, 1, description);
                } else if (noteIndex == PAD_STOP_SAMPLERS_ID) {
                    evtStopSamplers.broadcast();
                    "Stop all loops" => description;
                    logToOsc(1, PAD_SPAWN_SAMPLER_ID, 0, description);
                } else if (noteIndex == PAD_ENABLE_SAMPLER_ID) {
                    // 1 => samplerGain.gain;
                    1 => sacrificeEnv.keyOn;
                    // 0 => inputGain.gain;
                    "journey to outer space" => description;
                    logToOsc(1, noteIndex, 1, description);
                }
            } else if (msg.data1 == 137) { // note off
                msg.data2 - 36 => int noteIndex;
                if (noteIndex == PAD_ENABLE_SAMPLER_ID) {
                    // 0 => samplerGain.gain;
                    1 => sacrificeEnv.keyOff;
                    // 1 => inputGain.gain;
                    "nevermind" => description;
                    logToOsc(1, noteIndex, 0, description);
                }
            } else if (msg.data1 == 176) { // knob twist
                (msg.data3 $ float) / 127.0 => float amount;
                if (msg.data2 == SLIDER_BEND_LO_ID) {
                    amount => gBendLo;
                    evtParam.broadcast();
                    "bend lo " + gBendLo => description;
                } else if (msg.data2 == SLIDER_BEND_TOP_ID) {
                    amount => gBendTop;
                    evtParam.broadcast();
                    "bend top " + gBendTop => description;
                } else if (msg.data2 == SLIDER_MONITOR_ID) {
                    amount * 0.55 => monitorGain.gain;
                    "monitor " + amount => description;
                } else if (msg.data2 == SLIDER_SHIFT_GAIN_ID) {
                    amount * 0.65 => sacrificeEnv.gain;
                    "sampler gain " + amount => description;
                } else if (msg.data2 == SLIDER_SHIFT_SAMPLER_ID) {
                    1.0 - amount => gShiftSampler;
                    evtParam.broadcast();
                    "shift sampler " + gShiftSampler => description;
                }
                logToOsc(0, msg.data2, msg.data3, description);
            }
            if (description != " ") {
                <<< description >>>;
            }
        }
    }
}

class Sacrifice {
    ADSR _envs[4];
    
    fun void run(UGen in, UGen shiftGain, UGen out) {
        for (0 => int ii; ii < _envs.cap(); ii++) {
            _envs[ii].set(4::second, 1::second, 1.0, 6::second);
            0.4 => _envs[ii].gain;
        }
        
        in => PitShift lo => _envs[0] => shiftGain => out;
        1 => lo.mix;
        shift(3.0) => lo.shift;
        
        in => PitShift mid => _envs[1] => shiftGain => out;
        1 => mid.mix;
        shift(7.0) => mid.shift;
        
        in => PitShift top => _envs[2] => shiftGain => out;
        1 => top.mix;
        shift(10.0) => top.shift;

        in => PitShift harm => _envs[3] => shiftGain => out;
        1 => harm.mix;
        0.4 => harm.gain;
        shift(12.0 + 12.0 + 2.0) => harm.shift;

        in => shiftGain => out;

        spork ~ _listenForEnvelope();
        while (evtParam => now) {
            shift(3.0 + gBendLo * 2.0) => lo.shift;
            shift(10.0 + gBendTop * 2.0) => top.shift;
        }
    }

    fun void _listenForEnvelope() {
        while (evtEnvelope => now) {
            if (evtEnvelope.index >= _envs.cap()) {
                return;
            }
            if (evtEnvelope.on) {
                1 => _envs[evtEnvelope.index].keyOn;
            } else {
                1 => _envs[evtEnvelope.index].keyOff;
            }
        }
    }
}

class Sampler {
    0 => int _isStopped;
    ADSR _env;
    PitShift _shift;

    fun void loop(UGen in, UGen out) {
        in => LiSa buf => _shift => _env => out;
        1 => _shift.mix;
        gShiftSampler => _shift.shift;
        _env.set(0.1::second, 0.1::second, 0.9, 0.1::second);

        2::second => dur sampleLength;
        sampleLength => buf.duration;
        buf.recRamp(10::ms);
        buf.record(1);
        sampleLength => now;
        buf.record(0);

        buf.play(1);
        1 => _env.keyOn;
        spork ~ _listenForStop();
        spork ~ _listenForParam();
        while (!_isStopped) {
            sampleLength => now;
        }
        1 => _env.keyOff;
        _env.releaseTime() => now;
        _env =< out;
    }

    fun void _listenForStop() {
        evtStopSamplers => now;
        1 => _isStopped;
    }

    fun void _listenForParam() {
        while (evtParam => now) {
            gShiftSampler => _shift.shift;
        }
    }
}

fun float shift(float interval) {
    return Math.pow(2.0, interval / 12.0);
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
}

inputGain => wetGain;

spork ~ listenForMidi();

Sacrifice s;
spork ~ s.run(samplerGain, shiftGain, sacrificeEnv);

monitorGain => dac;

while (1::day => now);
