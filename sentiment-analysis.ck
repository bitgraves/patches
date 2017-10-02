
1 => int midiDeviceIndex;
1 => int enableOsc;

0 => float grainLengthScalar;
0 => float panVoice;
0 => int noteOffsetAmount;
0 => int octIndex;
0 => int noteIndex;
[ 0, 0, 0, 0, 0, 0, 0, 0 ] @=> int isAlive[];
[ 0, 0, 0, 0, 0, 0, 0, 0 ] @=> int isCapturing[];

// [ 0, 2, 3, 5, 7, 8, 10, 12 ] @=> int minorScale[];
[ -12, 12, 12, 7, 5 ] @=> int minorScale[];

adc.left => Gain monitor => dac.left;
LPF lpf => HPF hpf => dac.right;
20000 => lpf.freq;
0.98 => lpf.Q;
0 => monitor.gain;
20 => hpf.freq;
0.87 => hpf.Q;

Event evtStop;

1 => int PARAM_GRAIN_LENGTH;
2 => int PARAM_PAN;
3 => int PARAM_OCT_INDEX;
4 => int PARAM_NOTE_INDEX;
5 => int PARAM_NOTE_OFFSET;
class ParamEvent extends Event {
    0 => int param;
}

ParamEvent evtParam;
OscSend oscTransmitter;

fun void listenForMidi() {
    MidiIn min;
    MidiMsg msg;
    if (!min.open(midiDeviceIndex)) me.exit();
    while (true) {
        min => now;
        while (min.recv(msg)) {
            if (msg.data1 == 176) { // knob twist
                "" => string description;
                if (msg.data2 == 3) {
                    ((msg.data3 $ float) / 127.0) * 0.9 => grainLengthScalar;
                    PARAM_GRAIN_LENGTH => evtParam.param;
                    evtParam.broadcast();
                    <<< "Grain length:", grainLengthScalar >>>;
                } else if (msg.data2 == 9) {
                    (((msg.data3 $ float) / 127.0) * 8.0) $ int => noteOffsetAmount;
                    PARAM_NOTE_OFFSET => evtParam.param;
                    evtParam.broadcast();
                    <<< "Spread:", noteOffsetAmount >>>;
                    noteOffsetAmount + " spr" => description;
                } else if (msg.data2 == 12) {
                    (((msg.data3 $ float) / 127.0) * 5.0) $ int => octIndex;
                    PARAM_OCT_INDEX => evtParam.param;
                    evtParam.broadcast();
                    <<< "Octave:", octIndex >>>;
                    "oct " + octIndex => description;
                } else if (msg.data2 == 13) {
                    // (((msg.data3 $ float) / 127.0) * 12.0) $ int => noteIndex;
                    // PARAM_NOTE_INDEX => evtParam.param;
                    // evtParam.broadcast();
                    // <<< "Note index:", noteIndex >>>;
                    msg.data3 $ float / 127.0 => float val;
                    Math.min(19000.0, 20.0 + Math.pow(2, val * 14.287)) => hpf.freq;
                    <<< "Hipass", hpf.freq() >>>;
                    hpf.freq() + " hi Hz" => description;
                } else if (msg.data2 == 14) {
                    (msg.data3 $ float) / 127.0 => monitor.gain;
                    <<< "Monitor:", monitor.gain() >>>;
                    monitor.gain() * 100 + "%" => description;
                } else if (msg.data2 == 15) {
                    msg.data3 $ float / 127.0 => float val;
                    Math.pow(2, val * 14.28) => lpf.freq;
                    <<< "Lowpass", lpf.freq() >>>;
                    lpf.freq() + " lo Hz" => description;
                } else if (msg.data2 == 16) {
                    ((msg.data3 $ float) / 64.0) - 1.0 => panVoice;
                    PARAM_PAN => evtParam.param;
                    evtParam.broadcast();
                    <<< "Pan:", panVoice >>>;
                }
                if (enableOsc) {
                    // 0 -> knob
                    transmitOscValue(0, msg.data2, msg.data3, description);
                }
            } else if (msg.data1 == 153) { // pad hit
                msg.data2 - 36 => int index;
                if (index == 0) {
                    evtStop.broadcast();
                    <<< "Release" >>>;
                } else if (index == 1) {
                    spawnGroup(0, 3);
                } else if (index == 2) {
                    spawnGroup(4, 7);
                } else if (index >= 4 && index < 8) {
                    spawnPair(index - 4);
                } else if (index >= 8 && index < 16) {
                    index - 8 => int captureIndex;
                    spawn(captureIndex, grainLengthScalar, octIndex);
                    1 => isCapturing[captureIndex];
                }
            } else if (msg.data1 == 137) { // pad release
                msg.data2 - 36 => int index;
                if (index >= 8 && index < 16) {
                    index - 8 => int captureIndex;
                    0 => isCapturing[captureIndex];
                }
            } else {
                // <<< msg.data1, msg.data2, msg.data3 >>>;
            }
        }
    }
}

fun void spawnPair(int mainIdx) {
    spawn(mainIdx, grainLengthScalar, octIndex);
    spawn(mainIdx + 4, grainLengthScalar, octIndex + 5);
}

fun void spawnGroup(int lowIdx, int hiIdx) {
    <<< "Spawn group", lowIdx, hiIdx >>>;
    octIndex => int groupOctIndex;
    for (lowIdx => int ii; ii <= hiIdx; ii++) {
        spawn(ii,
              Math.min(1.0, grainLengthScalar + (ii * 0.07)),
              groupOctIndex
            );
        if (ii >= lowIdx + 2) {
            groupOctIndex++;
        }
        ((Math.random() % 25) + 1)::ms => now;
    }
}

fun void spawn(int captureIndex, float initialGrainLength, int initialOctIndex) {
    if (enableOsc) {
        // 1 -> pad
        transmitOscValue(1, captureIndex + 8, 1, "");
    }
    <<< "initial grain length:", initialGrainLength >>>;
    if (!isAlive[captureIndex]) {
        <<< "  Spawn", captureIndex >>>;
        Wash w;
        spork ~ w.run(adc.left, lpf, captureIndex, initialGrainLength, initialOctIndex);
        1 => isAlive[captureIndex];
    }
}

class Wash {
    0::second => dur _grainSustain;
    0::second => dur _grainAttack;
    0::second => dur _grainRelease;
    0::second => dur _grainLength;
    0 => int _stopped;
    0 => int _captureIndex;
    0 => int _octIndex;
    0 => int _noteIndex;
    3 => int _noteOffsetAmount;
    0 => int _noteOffset;
    ADSR _sampEnv;
    PitShift _shift;
    Pan2 _pan;

    fun void run(UGen input, UGen output,
                 int captureIndex,
                 float initialGrainLength, int initialOctIndex) {
        captureIndex => _captureIndex;
        computeSampLengths(initialGrainLength);
        computeNoteOffset(noteOffsetAmount);
        computePitshift(initialOctIndex, noteIndex, _noteOffset);
        computePan(panVoice);
        
        input => LiSa buf
            => _sampEnv => _shift => ADSR voiceEnv => _pan
            => output;
        voiceEnv.set(
            _grainAttack + initialOctIndex::second,
            0::second, 1.0,
            (5 + initialOctIndex)::second
            );
        1 => _shift.mix;

        // record grain
        _grainLength => buf.duration;
        buf.recRamp(5::ms);
        buf.record(1);
        _grainLength => now;
        buf.record(0);

        spork ~ listenForParams();
        spork ~ listenForStop(voiceEnv);
        buf.play(1);
        while (!_stopped) {
            _sampEnv.set(_grainAttack, 0::second, 1.0, _grainRelease);
            1 => _sampEnv.keyOn;
            _grainAttack => now;
            _grainLength => now;
            1 => _sampEnv.keyOff;
            _grainRelease => now;
            computeNoteOffset(_noteOffsetAmount);
        }

        buf.play(0);
        buf =< output;
    }

    fun void computeNoteOffset(int noteOffsetAmount) {
        noteOffsetAmount => _noteOffsetAmount;
        0 => _noteOffset;
        0 => int idx;
        for (0 => int ii; ii < _noteOffsetAmount; ii++) {
            if (Math.randomf() < 0.4) {
                minorScale[idx++ % minorScale.cap()] +=> _noteOffset;
            }
        }
        computePitshift(_octIndex, _noteIndex, _noteOffset);
    }

    fun void computeSampLengths(float scalar) {
        (0.02 + (0.18 * scalar))::second => _grainSustain;
        (0.005 + (0.02 * scalar))::second => _grainAttack;
        (0.01 + (0.07 * scalar))::second => _grainRelease;
        _grainSustain + _grainAttack + _grainRelease => _grainLength;
    }

    fun void computePan(float p) {
        p => _pan.pan;
    }

    fun void computePitshift(int octIndex, int noteIdx, int noteOffset) {
        octIndex => _octIndex;
        noteIdx => _noteIndex;
        noteOffset => _noteOffset;
        (octIndex * 12) + noteIdx + _noteOffset => int idx;
        Math.pow(2, (idx / 12.0)) => _shift.shift;
        1.0 - (octIndex * 0.15) => _shift.gain;
        if (noteOffset > 0 && Math.randomf() < 0.2) {
            0.2 => _shift.gain;
        }
    }

    fun void listenForParams() {
        while (evtParam => now) {
            if (isCapturing[_captureIndex]) {
                if (evtParam.param == PARAM_GRAIN_LENGTH) {
                    computeSampLengths(grainLengthScalar);
                } else if (evtParam.param == PARAM_PAN) {
                    computePan(panVoice);
                } else if (evtParam.param == PARAM_OCT_INDEX) {
                    computePitshift(octIndex, _noteIndex, _noteOffset);
                } else if (evtParam.param == PARAM_NOTE_INDEX) {
                    computePitshift(_octIndex, noteIndex, _noteOffset);
                } else if (evtParam.param == PARAM_NOTE_OFFSET) {
                    computeNoteOffset(noteOffsetAmount);
                }
            }
            if (_stopped) { break; }
        }
    }

    fun void listenForStop(ADSR env) {
        1 => env.keyOn;
        env.attackTime() + env.decayTime() => now;
        while (evtStop => now) {
            if (isCapturing[_captureIndex]) {
                <<< "  Stop", _captureIndex >>>;
                break;
            } else {
                <<< "    Still alive: ", _captureIndex >>>;
            }
        }
        1 => env.keyOff;
        0 => isAlive[_captureIndex];
        if (enableOsc) {
            // 1 -> pad
            transmitOscValue(1, _captureIndex + 8, 0, "");
        }
        env.releaseTime() => now;
        1 => _stopped;
    }
}

fun void transmitOscValue(int type, int param, int value, string description) {
    oscTransmitter.startMsg("/param", "i i i s");
    type => oscTransmitter.addInt;
    param => oscTransmitter.addInt;
    value => oscTransmitter.addInt;
    description => oscTransmitter.addString;
    return;
}

if (enableOsc) {
    oscTransmitter.setHost("localhost", 4242);
}
spork ~ listenForMidi();

while (1::day => now);

