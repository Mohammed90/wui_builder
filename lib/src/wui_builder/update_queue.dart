import 'dart:html';

import 'component.dart';
import 'cursors.dart';
import 'update_processor.dart';
import 'update_tracker.dart';
import 'velement.dart';

List<UpdateTracker> activeUpdates = [];
int pendingIdleId;

void requestIdle() {
  // request idle time to render
  pendingIdleId = window.requestIdleCallback(runIdle);
}

void runIdle(IdleDeadline deadline) {
  // run the update cycle for each update in the queue
  while (!activeUpdates.isEmpty) {
    // remove the update at the head of the queue and resume it
    final update = activeUpdates.removeAt(0);
    resumeUpdate(deadline, update);

    // break out of the loop if the timeout is hit
    if (deadline.timeRemaining() < 1) break;
  }

  // nullify pendingIdleId to indicate no idle callback is being waited for
  pendingIdleId = null;

  // if there are still updates in the queue request idle time
  if (activeUpdates.length > 0) requestIdle();
}

void queueNewUpdate(UpdateTracker tracker) {
  // add the tracker to the queue
  activeUpdates.add(tracker);

  // request idle time if necessary
  if (pendingIdleId == null) requestIdle();
}

void queueProcessingUpdate(UpdateTracker tracker) {
  // add the tracker to the queue
  activeUpdates.insert(0, tracker);

  // request idle time if necessary
  if (pendingIdleId == null) requestIdle();
}

void resumeUpdate(IdleDeadline deadline, UpdateTracker tracker) {
  // if the deadline has been cancelled bail
  if (tracker.isCancelled) return;

  // update the deadline on the tracker and update it
  tracker.refresh(deadline);
  final finished = updateVNode(tracker);

  // if the current update stack was completed
  // resume its parents updates
  if (finished) doPendingWork(tracker);
}

void doPendingWork(UpdateTracker tracker) {
  // pop work of the queue until the tracker is complete or paused
  var finished = true;
  while (!tracker.pendingCursors.isEmpty) {
    if (tracker.pendingCursors.last.cursorType == PendingCursors.Iterable) {
      finished = updateElementChildren(tracker);
    } else {
      finishComponentUpdate(tracker);
      finished = true;
    }
    if (!finished) return;
  }
}
