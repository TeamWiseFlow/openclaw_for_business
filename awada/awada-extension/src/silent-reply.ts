/**
 * Returns true when text is the silent sentinel (NO_REPLY), ignoring surrounding whitespace.
 */
export function isNoReplyText(text: string | undefined | null): boolean {
  if (!text) return false;
  return /^\s*NO_REPLY\s*$/i.test(text);
}
