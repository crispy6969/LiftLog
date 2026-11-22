import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../exercises/data/tracker_repository.dart';
import '../models/entry.dart';

class EntryController extends ChangeNotifier {
  EntryController(this.repository, this.exerciseId);
  final TrackerRepository repository;
  final int exerciseId;
  EntryDraft draft = EntryDraft.empty();
  List<ExerciseEntry> entries = [];
  ExerciseEntry? preceding;
  bool loading = true;
  bool busy = false;
  bool hasDraft = false;
  bool hasMore = false;
  bool persisting = false;
  Object? error;
  Object? draftError;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    _emit();
    try {
      final restored = await repository.draft(exerciseId);
      hasDraft = restored != null;
      await _history();
      draft = restored ?? _newDraft();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      _emit();
    }
  }

  Future<void> _history() async {
    final rows = await repository.history(exerciseId, limit: 31);
    hasMore = rows.length > 30;
    preceding = hasMore ? rows.last : null;
    entries = rows.take(30).toList();
  }

  EntryDraft _newDraft() => EntryDraft.empty(
    setCount: entries.isEmpty ? 1 : entries.first.sets.length,
  );

  ExerciseEntry? get comparison {
    for (final entry in entries) {
      if (entry.id != draft.editingEntryId) return entry;
    }
    return null;
  }

  Future<void> more() async {
    if (busy) return;
    busy = true;
    _emit();
    try {
      final rows = await repository.history(
        exerciseId,
        offset: entries.length,
        limit: 31,
      );
      hasMore = rows.length > 30;
      preceding = hasMore ? rows.last : null;
      entries.addAll(rows.take(30));
    } finally {
      busy = false;
      _emit();
    }
  }

  void changed() {
    if (busy || loading) return;
    hasDraft = true;
    persisting = true;
    draftError = null;
    // Snapshot immediately: queued writes must not observe later edits.
    final snapshot = EntryDraft.decode(
      draft.encode(),
      editingEntryId: draft.editingEntryId,
    );
    _queue = _queue.then((_) async {
      try {
        await repository.saveDraft(exerciseId, snapshot);
        draftError = null;
      } catch (e) {
        draftError = e;
      }
    });
    final current = _queue;
    unawaited(
      current.then((_) {
        if (identical(current, _queue)) {
          persisting = false;
          _emit();
        }
      }),
    );
    _emit();
  }

  Future<bool> flush() async {
    await _queue;
    return draftError == null;
  }

  Future<void> discard() async {
    busy = true;
    _emit();
    try {
      await _queue;
      await repository.discardDraft(exerciseId);
      hasDraft = false;
      draftError = null;
      draft = _newDraft();
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> edit(ExerciseEntry entry) async {
    await discard();
    draft = EntryDraft.fromEntry(entry);
    changed();
  }

  Future<void> save() async {
    draft.validate();
    busy = true;
    _emit();
    try {
      await _queue;
      await repository.saveEntry(exerciseId, draft);
      hasDraft = false;
      draftError = null;
      await _history();
      draft = _newDraft();
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> delete(ExerciseEntry entry) async {
    busy = true;
    _emit();
    try {
      await _queue;
      await repository.deleteEntry(entry.id);
      if (draft.editingEntryId == entry.id) {
        draft = EntryDraft.empty();
        hasDraft = false;
      }
      await _history();
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
