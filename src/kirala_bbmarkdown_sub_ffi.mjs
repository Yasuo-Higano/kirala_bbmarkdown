export function format(fmt,args) {
    return fmt.replace(/~t/g, args[0]);
}