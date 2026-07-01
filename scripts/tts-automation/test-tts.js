import { MsEdgeTTS, OUTPUT_FORMAT } from 'msedge-tts';

async function test() {
    const tts = new MsEdgeTTS();
    await tts.setMetadata("mn-MN-YesuiNeural", OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
    
    const { audioStream } = tts.toStream("Hello world");
    
    const chunks = [];
    audioStream.on('data', chunk => chunks.push(chunk));
    audioStream.on('end', () => {
        const buffer = Buffer.concat(chunks);
        console.log("Buffer length:", buffer.length);
    });
}
test().catch(console.error);
