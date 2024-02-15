let check = true;

const promise1 = new Promise((resolve , reject)=>{
    if(check){
        resolve("Promise Başarılı")
    }else{
        reject("Promise Başarısız...")
    }
})

console.log(promise1)

let check = true;
function createPromise(){
    return new Promise((resolve , reject)=>{
        if(check){
            resolve("Promise te herhangi bir sıkıntı yok.")
        }else{
            reject("Promise sıkıntılı!!")
        }
    })
}

createPromise()
.then((response)=>{
    console.log(response)
})
.catch((err)=>{
    console.log(err)
})
.finally(()=> console.log("her zaman çalışır"))
