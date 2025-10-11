export default {
    extends: ['@commitlint/config-conventional'],
    ignores: [
        // Ignore auto-generated merge commits (e.g., "Merge branch ...", "Merge remote-tracking branch ...", "Merge pull request ...")
        (message) => /^Merge( branch| remote-tracking branch| pull request| tag|\s)/.test(message),
        // Ignore the initial bootstrapping commit
        (message) => message.trim() === 'Initial commit',
    ],
    // Customize rules if needed
    rules: {
        // Increase the max length of the full header line (type(scope)!: subject)
        'header-max-length': [2, 'always', 200],
        // Double the maximum length of the subject line
        'subject-max-length': [2, 'always', 200],
        // Optional: allow longer lines in body and footer
        'body-max-line-length': [2, 'always', 200],
        'footer-max-line-length': [2, 'always', 200],
    }
};
