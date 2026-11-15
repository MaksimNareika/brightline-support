/**
 * Setup smoke test S9 — DO NOT MERGE. Calls a class that does not exist, so `validate` must fail
 * with "Invalid type: NoSuchClass" and block the merge.
 */
public with sharing class SmokeTriage {
    public static void run() {
        NoSuchClass.run();
    }
}
