let io;

function setIo(socketIo) {
  io = socketIo;
}

function getIo() {
  return io;
}

module.exports = { setIo, getIo };
