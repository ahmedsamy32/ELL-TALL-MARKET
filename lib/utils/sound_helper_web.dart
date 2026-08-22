// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

/// Request Web Desktop Notification permissions and set up user interaction listener for audio autoplay
void requestNotificationPermissions() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        if (window.Notification && Notification.permission !== 'granted' && Notification.permission !== 'denied') {
          Notification.requestPermission();
        }
        window.addEventListener('click', function() {
          try {
            var AudioContext = window.AudioContext || window.webkitAudioContext;
            if (AudioContext) {
              var ctx = new AudioContext();
              if (ctx.state === 'suspended') { ctx.resume(); }
            }
          } catch(e) {}
        }, { once: true });
      })();
      '''
    ]);
  } catch (_) {}
}

/// Plays a clear 2-tone notification chime via Web Audio API
void playNotificationSound() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        try {
          var AudioContext = window.AudioContext || window.webkitAudioContext;
          if (AudioContext) {
            var ctx = new AudioContext();
            if (ctx.state === 'suspended') { ctx.resume(); }
            var now = ctx.currentTime;
            
            var osc1 = ctx.createOscillator();
            var gain1 = ctx.createGain();
            osc1.type = 'sine';
            osc1.frequency.setValueAtTime(587.33, now);
            gain1.gain.setValueAtTime(0.35, now);
            gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
            osc1.connect(gain1);
            gain1.connect(ctx.destination);
            osc1.start(now);
            osc1.stop(now + 0.3);

            var osc2 = ctx.createOscillator();
            var gain2 = ctx.createGain();
            osc2.type = 'sine';
            osc2.frequency.setValueAtTime(880, now + 0.12);
            gain2.gain.setValueAtTime(0.45, now + 0.12);
            gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.5);
            osc2.connect(gain2);
            gain2.connect(ctx.destination);
            osc2.start(now + 0.12);
            osc2.stop(now + 0.5);
          }
        } catch (e) {}

        try {
          var audio = new Audio('https://assets.mixkit.co/active_storage/sfx/2869/2869-200.wav');
          audio.play().catch(function(){});
        } catch(e) {}
      })();
      '''
    ]);
  } catch (_) {}
}

/// Displays a native OS Web Desktop Notification Toast (WhatsApp Web style)
void showPlatformDesktopNotification({required String title, required String body}) {
  try {
    final safeTitle = title.replaceAll("'", "\\'").replaceAll('\n', ' ');
    final safeBody = body.replaceAll("'", "\\'").replaceAll('\n', ' ');
    js.context.callMethod('eval', [
      '''
      (function() {
        if (window.Notification && Notification.permission === 'granted') {
          var notif = new Notification('$safeTitle', {
            body: '$safeBody',
            icon: 'favicon.png',
            tag: 'ell_tall_market_' + Date.now()
          });
          notif.onclick = function() {
            window.focus();
          };
        } else if (window.Notification && Notification.permission !== 'denied') {
          Notification.requestPermission().then(function(permission) {
            if (permission === 'granted') {
              var notif = new Notification('$safeTitle', {
                body: '$safeBody',
                icon: 'favicon.png'
              });
              notif.onclick = function() {
                window.focus();
              };
            }
          });
        }
      })();
      '''
    ]);
  } catch (_) {}
}
