// lib/features/zara_engine/models/zara_state.dart
// Z.A.R.A. — Immutable State Model v2.0
// ✅ ChatMessage model (role, text, timestamp, id)
// ✅ isSpeaking + isProcessing flags for UI
// ✅ currentChatId for active session tracking
// ✅ Full toMap/fromMap sync

import 'package:battery_plus/battery_plus.dart';
import 'package:zara/core/enums/mood_enum.dart';

// ─── Chat Message (single bubble) ─────────────────────────────────────────
enum MessageRole { user, zara, system }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final bool isEdited;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
  });

  ChatMessage copyWith({String? text, bool? isEdited}) => ChatMessage(
        id:        id,
        role:      role,
        text:      text      ?? this.text,
        timestamp: timestamp,
        isEdited:  isEdited  ?? this.isEdited,
      );

  Map<String, dynamic> toMap() => {
        'id':        id,
        'role':      role.name,
        'text':      text,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isEdited':  isEdited,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id:        m['id'] as String? ?? UniqueKey.id(),
        role:      MessageRole.values.firstWhere(
                     (r) => r.name == m['role'],
                     orElse: () => MessageRole.user,
                   ),
        text:      m['text'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
                     m['timestamp'] as int? ??
                     DateTime.now().millisecondsSinceEpoch,
                   ),
        isEdited:  m['isEdited'] as bool? ?? false,
      );

  // Factory helpers
  factory ChatMessage.fromUser(String text) => ChatMessage(
        id:        UniqueKey.id(),
        role:      MessageRole.user,
        text:      text,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.fromZara(String text) => ChatMessage(
        id:        UniqueKey.id(),
        role:      MessageRole.zara,
        text:      text,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.system(String text) => ChatMessage(
        id:        UniqueKey.id(),
        role:      MessageRole.system,
        text:      text,
        timestamp: DateTime.now(),
      );
}

// Simple unique id helper (no external package needed)
class UniqueKey {
  static int _counter = 0;
  static String id() =>
      '${DateTime.now().millisecondsSinceEpoch}_${++_counter}';
}

// ─── Chat Session (sidebar archive entry) ─────────────────────────────────
class ChatSession {
  final String id;
  final String topicName;
  final List<String> messages;   // legacy string list (kept for compat)
  final List<ChatMessage> chatMessages; // new rich messages
  final DateTime timestamp;

  ChatSession({
    required this.id,
    required this.topicName,
    required this.messages,
    this.chatMessages = const [],
    required this.timestamp,
  });

  String get preview {
    if (chatMessages.isNotEmpty) {
      final last = chatMessages.last.text;
      return last.length > 40 ? '${last.substring(0, 40)}…' : last;
    }
    if (messages.isNotEmpty) {
      final last = messages.last;
      return last.length > 40 ? '${last.substring(0, 40)}…' : last;
    }
    return 'Empty chat';
  }

  int get messageCount =>
      chatMessages.isNotEmpty ? chatMessages.length : messages.length;

  Map<String, dynamic> toMap() => {
        'id':           id,
        'topicName':    topicName,
        'messages':     messages,
        'chatMessages': chatMessages.map((m) => m.toMap()).toList(),
        'timestamp':    timestamp.millisecondsSinceEpoch,
      };

  factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
        id:           m['id'] as String? ?? UniqueKey.id(),
        topicName:    m['topicName'] as String? ?? 'Chat',
        messages:     List<String>.from(m['messages'] ?? []),
        chatMessages: m['chatMessages'] != null
            ? List<ChatMessage>.from(
                (m['chatMessages'] as List).map(
                  (x) => ChatMessage.fromMap(Map<String, dynamic>.from(x)),
                ),
              )
            : [],
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          m['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
}

// ─── Security Models ───────────────────────────────────────────────────────
enum AlertSeverity { low, medium, high, critical }

class SecurityAlert {
  final String id;
  final String message;
  final AlertSeverity severity;
  final DateTime time;

  SecurityAlert({
    required this.id,
    required this.message,
    this.severity = AlertSeverity.medium,
    required this.time,
  });
}

class AutomationTask {
  final String id;
  final String description;
  final String status;
  final DateTime timestamp;

  AutomationTask({
    required this.id,
    required this.description,
    required this.status,
    required this.timestamp,
  });
}

// ─── Z.A.R.A. State ────────────────────────────────────────────────────────
class ZaraState {
  final bool isActive;
  final Mood mood;
  final String currentTopic;
  final String currentChatId;      // ✅ NEW: active session ID
  final String lastCommand;
  final String lastResponse;
  final DateTime lastActivity;
  final double pulseValue;
  final double orbScale;
  final double glowIntensity;
  final int affectionLevel;
  final String ownerName;

  // ✅ NEW: rich message list (replaces plain string dialogueHistory)
  final List<ChatMessage> messages;

  // Legacy — kept for backward compat with older persisted data
  final List<String> dialogueHistory;

  final List<ChatSession> chatArchives;
  final int batteryLevel;
  final BatteryState batteryState;
  final String deviceModel;
  final bool isWifiConnected;
  final int availableStorageMB;
  final int totalStorageMB;
  final bool isGuardianActive;
  final int intruderAttempts;
  final List<SecurityAlert> alerts;
  final String? lastIntruderPhoto;
  final List<AutomationTask> tasks;
  final bool isAnalyzingCode;

  // ✅ NEW: UI state flags
  final bool isProcessing;   // AI response incoming
  final bool isSpeaking;     // TTS playing
  final bool isListening;    // STT recording
  final bool ttsEnabled;     // auto-speak toggle

  const ZaraState({
    required this.isActive,
    required this.mood,
    required this.currentTopic,
    required this.currentChatId,
    required this.lastCommand,
    required this.lastResponse,
    required this.lastActivity,
    required this.pulseValue,
    required this.orbScale,
    required this.glowIntensity,
    required this.affectionLevel,
    required this.ownerName,
    required this.messages,
    required this.dialogueHistory,
    required this.chatArchives,
    required this.batteryLevel,
    required this.batteryState,
    required this.deviceModel,
    required this.isWifiConnected,
    required this.availableStorageMB,
    required this.totalStorageMB,
    required this.isGuardianActive,
    required this.intruderAttempts,
    required this.alerts,
    this.lastIntruderPhoto,
    required this.tasks,
    required this.isAnalyzingCode,
    required this.isProcessing,
    required this.isSpeaking,
    required this.isListening,
    required this.ttsEnabled,
  });

  factory ZaraState.initial() => ZaraState(
        isActive:           false,
        mood:               Mood.calm,
        currentTopic:       'SYSTEM INITIALIZED',
        currentChatId:      UniqueKey.id(),
        lastCommand:        '',
        lastResponse:       'Ummm... System Online. Ready for your commands, Sir. 💙',
        lastActivity:       DateTime.now(),
        pulseValue:         0.0,
        orbScale:           1.0,
        glowIntensity:      0.5,
        affectionLevel:     85,
        ownerName:          'OWNER RAVI',
        messages:           [],
        dialogueHistory:    [],
        chatArchives:       [],
        batteryLevel:       0,
        batteryState:       BatteryState.unknown,
        deviceModel:        'SYNCHRONIZING...',
        isWifiConnected:    false,
        availableStorageMB: 0,
        totalStorageMB:     0,
        isGuardianActive:   false,
        intruderAttempts:   0,
        alerts:             [],
        tasks:              [],
        isAnalyzingCode:    false,
        isProcessing:       false,
        isSpeaking:         false,
        isListening:        false,
        ttsEnabled:         true,   // ✅ Auto-speak ON by default
      );

  // ── Computed ──────────────────────────────────────────────────────────────
  double get systemIntegrity {
    double base = 100.0;
    if (batteryLevel < 15) base -= 20;
    if (isGuardianActive) base += 5;
    if (alerts.isNotEmpty) base -= (alerts.length * 10);
    return base.clamp(0, 100);
  }

  // ── Persistence ───────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'affectionLevel':  affectionLevel,
        'ownerName':       ownerName,
        'dialogueHistory': dialogueHistory,
        'messages':        messages.map((m) => m.toMap()).toList(),
        'chatArchives':    chatArchives.map((x) => x.toMap()).toList(),
        'isGuardianActive':isGuardianActive,
        'currentTopic':    currentTopic,
        'currentChatId':   currentChatId,
        'ttsEnabled':      ttsEnabled,
      };

  factory ZaraState.fromMap(Map<String, dynamic> map) {
    final initial = ZaraState.initial();
    return initial.copyWith(
      affectionLevel:  map['affectionLevel']  as int?    ?? 85,
      ownerName:       map['ownerName']       as String? ?? 'OWNER RAVI',
      dialogueHistory: List<String>.from(map['dialogueHistory'] ?? []),
      messages: map['messages'] != null
          ? List<ChatMessage>.from(
              (map['messages'] as List).map(
                (x) => ChatMessage.fromMap(Map<String, dynamic>.from(x)),
              ),
            )
          : [],
      chatArchives: map['chatArchives'] != null
          ? List<ChatSession>.from(
              (map['chatArchives'] as List).map(
                (x) => ChatSession.fromMap(Map<String, dynamic>.from(x)),
              ),
            )
          : [],
      isGuardianActive: map['isGuardianActive'] as bool?   ?? false,
      currentTopic:     map['currentTopic']     as String? ?? 'SYSTEM INITIALIZED',
      currentChatId:    map['currentChatId']    as String? ?? UniqueKey.id(),
      ttsEnabled:       map['ttsEnabled']       as bool?   ?? true,
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────
  ZaraState copyWith({
    bool?               isActive,
    Mood?               mood,
    String?             currentTopic,
    String?             currentChatId,
    String?             lastCommand,
    String?             lastResponse,
    DateTime?           lastActivity,
    double?             pulseValue,
    double?             orbScale,
    double?             glowIntensity,
    int?                affectionLevel,
    String?             ownerName,
    List<ChatMessage>?  messages,
    List<String>?       dialogueHistory,
    List<ChatSession>?  chatArchives,
    int?                batteryLevel,
    BatteryState?       batteryState,
    String?             deviceModel,
    bool?               isWifiConnected,
    int?                availableStorageMB,
    int?                totalStorageMB,
    bool?               isGuardianActive,
    int?                intruderAttempts,
    List<SecurityAlert>?alerts,
    String?             lastIntruderPhoto,
    List<AutomationTask>?tasks,
    bool?               isAnalyzingCode,
    bool?               isProcessing,
    bool?               isSpeaking,
    bool?               isListening,
    bool?               ttsEnabled,
  }) {
    return ZaraState(
      isActive:           isActive           ?? this.isActive,
      mood:               mood               ?? this.mood,
      currentTopic:       currentTopic       ?? this.currentTopic,
      currentChatId:      currentChatId      ?? this.currentChatId,
      lastCommand:        lastCommand        ?? this.lastCommand,
      lastResponse:       lastResponse       ?? this.lastResponse,
      lastActivity:       lastActivity       ?? this.lastActivity,
      pulseValue:         pulseValue         ?? this.pulseValue,
      orbScale:           orbScale           ?? this.orbScale,
      glowIntensity:      glowIntensity      ?? this.glowIntensity,
      affectionLevel:     affectionLevel     ?? this.affectionLevel,
      ownerName:          ownerName          ?? this.ownerName,
      messages:           messages           ?? this.messages,
      dialogueHistory:    dialogueHistory    ?? this.dialogueHistory,
      chatArchives:       chatArchives       ?? this.chatArchives,
      batteryLevel:       batteryLevel       ?? this.batteryLevel,
      batteryState:       batteryState       ?? this.batteryState,
      deviceModel:        deviceModel        ?? this.deviceModel,
      isWifiConnected:    isWifiConnected    ?? this.isWifiConnected,
      availableStorageMB: availableStorageMB ?? this.availableStorageMB,
      totalStorageMB:     totalStorageMB     ?? this.totalStorageMB,
      isGuardianActive:   isGuardianActive   ?? this.isGuardianActive,
      intruderAttempts:   intruderAttempts   ?? this.intruderAttempts,
      alerts:             alerts             ?? this.alerts,
      lastIntruderPhoto:  lastIntruderPhoto  ?? this.lastIntruderPhoto,
      tasks:              tasks              ?? this.tasks,
      isAnalyzingCode:    isAnalyzingCode    ?? this.isAnalyzingCode,
      isProcessing:       isProcessing       ?? this.isProcessing,
      isSpeaking:         isSpeaking         ?? this.isSpeaking,
      isListening:        isListening        ?? this.isListening,
      ttsEnabled:         ttsEnabled         ?? this.ttsEnabled,
    );
  }
}
