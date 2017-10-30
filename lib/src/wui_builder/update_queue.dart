part of wui_builder;

List<_UpdateTracker> _activeFibers = [];
int _pendingIdleId;

void _runIdle() {
  // request idle time to render
  _pendingIdleId = window.requestIdleCallback((deadline) {
    // run the update cycle for each update in the queue
    while (!_activeFibers.isEmpty) {
      // break out of the loop if the timeout is hit
      if (deadline.timeRemaining() < 1) break;

      // remove the update at the head of the queue and resume it
      final update = _activeFibers.removeAt(0);
      _resumeUpdate(deadline, update);
    }

    // nullify _pendingIdleId to indicate no idle callback is being waited for
    _pendingIdleId = null;

    // if there are still updates in the queue request idle time
    if (_activeFibers.length > 0) _runIdle();
  });
}

void _queueNewUpdate(_UpdateTracker tracker) {
  // add the tracker to the queue
  _activeFibers.add(tracker);

  // request idle time if necessary
  if (_pendingIdleId == null) _runIdle();
}

void _queueProcessingUpdate(_UpdateTracker tracker) {
  // add the tracker to the queue
  _activeFibers.insert(0, tracker);

  // request idle time if necessary
  if (_pendingIdleId == null) _runIdle();
}

void _resumeUpdate(IdleDeadline deadline, _UpdateTracker tracker) {
  // if the deadline has been cancelled bail
  if (tracker.isCancelled) return;

  // update the deadline on the tracker and update it
  tracker.refresh(deadline);
  _update(tracker);

  // if the current update stack was completed
  // resume its parents updates
  if (!tracker.isPaused) _doPendingWork(tracker);
}

void _doPendingWork(_UpdateTracker tracker) {
  // pop work of the queue until the tracker is complete or paused
  while (!tracker.pendingWork.isEmpty) {
    if (tracker.pendingWork.last is _ChildrenUpdate)
      _updateElementChildren(tracker);
    else
      _finishComponentUpdate(tracker);
    if (tracker.isPaused) return;
  }
}