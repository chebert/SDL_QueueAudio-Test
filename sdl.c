#include <SDL2/SDL.h>

#define MAX(a, b) ((a) < (b) ? (b) : (a))

const int k_frames_per_second = 60;
const int k_samples_per_second = 44100;
const int k_num_channels = 2;
const int k_bytes_per_channel = 2;
const int k_buffer_size_in_frames = 6;
const int k_device_id = 1;

int ms_per_frame() { return 1000 / k_frames_per_second; }

int bytes_per_sample() { return k_num_channels * k_bytes_per_channel; }
int samples_per_frame() { return k_samples_per_second / k_frames_per_second; }
int buffer_size_in_samples() { return k_buffer_size_in_frames * samples_per_frame(); }
int buffer_size_in_bytes() { return buffer_size_in_samples() * bytes_per_sample(); }

// Generate a channel's sample of a sine wave given the running sample_idx.
short sin_audio(int sample_idx, int freq) {
    short tone_volume = 3000;
    double time = sample_idx / (double)k_samples_per_second;
    double x = 2*3.14159*time;
    return (short)(tone_volume * sin(x * freq));
}

// Fill the audio buffer with two sine waves:
// left channel is A440
// right channel is A880
// Returns the updated running sample_idx
int enqueue_test_audio(int sample_idx) {
  const int bytes_written = SDL_GetQueuedAudioSize(1);
  const int num_bytes = MAX(buffer_size_in_bytes() - bytes_written, 0);
  const int num_samples = num_bytes / bytes_per_sample();
  printf("Bytes-written = %d\n", bytes_written);

  short *data = malloc(num_bytes);

  for (int i = 0; i < num_samples; ++i) {
    // Left channel
    data[2*i] = sin_audio(sample_idx, 440);
    // Right channel
    data[2*i + 1] = sin_audio(sample_idx, 880);
    ++sample_idx;
  }

  SDL_QueueAudio(k_device_id, data, num_bytes);
  free(data);
  return sample_idx;
}

int main(int argc, char **argv) {
  SDL_Init(SDL_INIT_EVERYTHING);

  {
    SDL_AudioSpec desired;
    desired.freq = k_samples_per_second;
    desired.format = AUDIO_S16LSB;
    desired.channels = k_num_channels;
    // Must be Power of 2
    desired.samples = 4096;
    // Use SDL_QueueAudio instead of providing callback
    desired.callback = 0;

    SDL_OpenAudio(&desired, 0);
  }
  
  // Start playing audio.
  SDL_PauseAudio(0);
  {
    int sample_idx = 0;
    for (int i = 0; i < 100; ++i) {
      sample_idx = enqueue_test_audio(sample_idx);

      // approximate timing of a game loop
      SDL_Delay(ms_per_frame());
    }
  }

  SDL_Quit();
  return 0;
}
