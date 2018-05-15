#!python3.6

import shoesvcmsg
import gencodeutil


def to_json(obj):
    return gencodeutil.to_json(obj, _name_mappings)


def from_json(return_type, obj):
    return gencodeutil.from_json(return_type, obj, _name_mappings)


_name_mappings = {
    shoesvcmsg.Fastening: gencodeutil.NameMapping({
        'laces': 'laces',
        'velcro': 'velcro'
    }),
    shoesvcmsg.Velcro: gencodeutil.NameMapping({
        'num_strips': 'numStrips'
    }),
    shoesvcmsg.Laces: gencodeutil.NameMapping({
        'length_cm': 'lengthCm',
        'color': 'color'
    }),
    shoesvcmsg.Color: gencodeutil.NameMapping({
        'RED': 'red',
        'GREEN': 'green',
        'BLUE': 'blue'
    }),
    shoesvcmsg.Shoe: gencodeutil.NameMapping({
        'color': 'color',
        'size_us': 'sizeUS',
        'fastening': 'fastening',
        'style': 'style'
    })
}
