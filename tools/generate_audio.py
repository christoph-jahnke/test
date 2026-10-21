import wave,math,random,struct
from pathlib import Path
audio_dir = Path(__file__).resolve().parents[1] / "audio"
audio_dir.mkdir(exist_ok=True)
rng=random.Random(7)
for name,duration,freq,noise in [('shot',.09,90,.7),('mortar',.3,55,.8),('cryo',.2,800,.1),('build',.22,520,.02),('wave',.5,230,.02),('alarm',.4,140,.04)]:
 data=[]
 for i in range(int(22050*duration)):
  t=i/22050;p=t/duration
  sample=(math.sin(math.tau*(freq*t*(1-.45*p))) *(1-noise)+rng.uniform(-1,1)*noise)*(1-p)**2*.42
  data.append(struct.pack('<h',int(sample*32767)))
 with wave.open(str(audio_dir/(name+'.wav')),'wb') as f:
  f.setparams((1,2,22050,0,'NONE','not compressed'));f.writeframes(b''.join(data))
